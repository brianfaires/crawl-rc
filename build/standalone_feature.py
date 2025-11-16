#!/usr/bin/env python3
"""
Standalone Feature Generator for BRC

Generates standalone feature files that can be copy-pasted into RC files
without requiring the full BRC core. Features are always active and called
directly from crawl's hooks.
"""

import re
import sys
from pathlib import Path
from typing import Set, Dict, List, Tuple, Optional

# Paths
base_dir = Path(__file__).parent.parent
core_dir = base_dir / "lua" / "core"
util_dir = base_dir / "lua" / "util"
features_dir = base_dir / "lua" / "features"
output_dir = base_dir / "bin" / "features"
output_dir.mkdir(parents=True, exist_ok=True)

# Known BRC modules and their file locations
BRC_MODULES = {
    "BRC.mpr": util_dir / "mpr.lua",
    "BRC.txt": util_dir / "text.lua",
    "BRC.Data": core_dir / "data.lua",
    "BRC.util": util_dir / "util.lua",
    "BRC.eq": util_dir / "equipment.lua",
    "BRC.it": util_dir / "item.lua",
    "BRC.opt": util_dir / "options.lua",
    "BRC.you": util_dir / "you.lua",
    "BRC.Hotkey": core_dir / "hotkey.lua",
    "BRC.Configs": core_dir / "config.lua",  # Note: This is BRC.Configs, not BRC.Config
}

# Constants that need to be included
BRC_CONSTANTS = core_dir / "constants.lua"
BRC_HEADER = core_dir / "_header.lua"

# Crawl hooks that features can use
CRAWL_HOOKS = {
    "ready": "ready",
    "autopickup": "autopickup",
    "c_answer_prompt": "c_answer_prompt",
    "c_assign_invletter": "c_assign_invletter",
    "c_message": "c_message",
    "ch_start_running": "ch_start_running",
}


class DependencyAnalyzer:
    """Analyzes a feature file to find its dependencies."""
    
    def __init__(self, feature_file: Path):
        self.feature_file = feature_file
        self.content = feature_file.read_text(encoding='utf-8')
        self.used_modules: Set[str] = set()
        self.used_functions: Dict[str, Set[str]] = {}
        self.used_constants: Set[str] = set()
        self.used_hooks: Set[str] = set()
        self.uses_persist = False
        self.uses_config = False
        self.uses_config_emojis = False
        
    def analyze(self):
        """Analyze the feature file for dependencies."""
        # Find BRC module usage (BRC.mpr, BRC.txt, etc.)
        for module in BRC_MODULES.keys():
            # Match patterns like BRC.mpr.something, BRC.txt.white(), etc.
            # Also match just BRC.Hotkey or BRC.Configs as standalone references
            pattern = rf'\b{re.escape(module)}\b'
            if re.search(pattern, self.content):
                self.used_modules.add(module)
                # Also check for function calls
                func_pattern = rf'\b{re.escape(module)}\.(\w+)'
                matches = re.findall(func_pattern, self.content)
                if matches:
                    if module not in self.used_functions:
                        self.used_functions[module] = set()
                    self.used_functions[module].update(matches)
        
        # Check for BRC.COL usage (needed for color functions)
        if re.search(r'\bBRC\.COL\b', self.content):
            self.used_constants.add("COL")
        
        # Check for BRC.EMOJI usage
        if re.search(r'\bBRC\.EMOJI\b', self.content):
            self.used_constants.add("EMOJI")
            self.uses_config_emojis = True  # EMOJI constants use BRC.Config.emojis
        
        # Check for BRC.Config.emojis usage
        if re.search(r'\bBRC\.Config\.emojis\b', self.content):
            self.uses_config_emojis = True
        
        # Check for other constants
        for const in ["MISC_ITEMS", "MISSILES", "SPELLBOOKS", "UNDEAD_RACES", 
                     "NONLIVING_RACES", "POIS_RES_RACES", "LITTLE_RACES", 
                     "SMALL_RACES", "LARGE_RACES", "MAGIC_SCHOOLS", 
                     "TRAINING_SKILLS", "WEAP_SCHOOLS", "HELL_BRANCHES",
                     "PORTAL_NAMES", "RISKY_EGOS", "NON_ELEMENTAL_DMG_EGOS",
                     "ADJECTIVE_EGOS", "ARTPROPS_BAD", "ARTPROPS_EGO", "KEYS",
                     "DMG_TYPE", "SIZE_PENALTY"]:
            if re.search(rf'\bBRC\.{const}\b', self.content):
                self.used_constants.add(const)
        
        # Check for BRC.Data.persist usage
        if re.search(r'\bBRC\.Data\.persist\b', self.content):
            self.uses_persist = True
            self.used_modules.add("BRC.Data")
        
        # Check for Config usage
        if re.search(r'\.Config\b', self.content):
            self.uses_config = True
        
        # Find which hooks the feature uses
        for hook_name in CRAWL_HOOKS.keys():
            pattern = rf'function\s+\w+\.{hook_name}\s*\('
            if re.search(pattern, self.content):
                self.used_hooks.add(hook_name)
        
        # Also check for init()
        if re.search(r'function\s+\w+\.init\s*\(', self.content):
            self.used_hooks.add("init")


class CodeExtractor:
    """Extracts needed code from BRC modules."""
    
    def __init__(self):
        self.cache: Dict[Path, str] = {}
    
    def read_file(self, file_path: Path) -> str:
        """Read and cache a file."""
        if file_path not in self.cache:
            self.cache[file_path] = file_path.read_text(encoding='utf-8')
        return self.cache[file_path]
    
    def extract_functions(self, module_content: str, function_names: Set[str], analyzer=None) -> Tuple[str, Set[str]]:
        """Extract specific functions from module content.
        Returns (extracted_code, additional_modules_needed)"""
        extracted = []
        lines = module_content.split('\n')
        i = 0
        extracted_funcs = set()
        additional_modules = set()
        
        while i < len(lines):
            line = lines[i]
            
            # Check if this is a function we need
            for func_name in function_names:
                if func_name in extracted_funcs:
                    continue
                    
                # Match function definitions: function BRC.module.func_name(...)
                # Also match local function definitions that might be helpers
                pattern = rf'^function\s+BRC\.\w+\.{re.escape(func_name)}\s*\('
                if re.match(pattern, line):
                    # Extract the function (including local helpers it might use)
                    func_lines = self._extract_function_block(lines, i)
                    func_code = '\n'.join(func_lines)
                    extracted.extend(func_lines)
                    extracted.append('')  # Blank line between functions
                    extracted_funcs.add(func_name)
                    
                    # Check for cross-module dependencies in the extracted function
                    if analyzer:
                        for module in BRC_MODULES.keys():
                            if module not in analyzer.used_modules:
                                pattern = rf'\b{re.escape(module)}\b'
                                if re.search(pattern, func_code):
                                    additional_modules.add(module)
                    break
            
            i += 1
        
        return '\n'.join(extracted), additional_modules
    
    def _extract_function_block(self, lines: List[str], start_idx: int) -> List[str]:
        """Extract a complete function block, preserving comments on closing braces."""
        result = []
        i = start_idx
        
        # Get initial indentation
        initial_indent = len(lines[i]) - len(lines[i].lstrip())
        
        # Track function/end pairs using indentation
        in_function = True
        result.append(lines[i])  # Add function declaration
        i += 1
        
        while i < len(lines):
            line = lines[i]
            if not line.strip():  # Empty line
                result.append(line)
                i += 1
                continue
            
            current_indent = len(line) - len(line.lstrip())
            
            # If we hit a line at the same or less indentation as the function declaration
            # and it's not a comment, we're done (unless it's an 'end' keyword)
            if current_indent <= initial_indent and line.strip() and not line.strip().startswith('--'):
                # Check if it's an 'end' that closes our function
                if line.strip() == 'end' and current_indent == initial_indent:
                    result.append(line)
                    break
                # Otherwise, we've moved past the function
                break
            
            result.append(line)
            i += 1
        
        return result
    
    def extract_module_setup(self, module_name: str, module_content: str) -> str:
        """Extract module initialization code."""
        # Extract the module table creation: BRC.module = {}
        pattern = rf'^BRC\.\w+\s*=\s*{{}}'
        lines = module_content.split('\n')
        setup = []
        
        for line in lines:
            if re.match(pattern, line):
                setup.append(line)
                break
        
        return '\n'.join(setup) if setup else f"BRC.{module_name.split('.')[1]} = {{}}"


class StandaloneGenerator:
    """Generates standalone feature files."""
    
    def __init__(self, analyzer: DependencyAnalyzer, extractor: CodeExtractor):
        self.analyzer = analyzer
        self.extractor = extractor
        self.feature_name = self._get_feature_name()
        self.feature_var = self._get_feature_var_name()
    
    def _get_feature_name(self) -> str:
        """Extract feature name from feature file."""
        # Look for BRC_FEATURE_NAME = "..."
        match = re.search(r'BRC_FEATURE_NAME\s*=\s*["\']([^"\']+)["\']', self.analyzer.content)
        if match:
            return match.group(1)
        # Fallback to filename
        return self.analyzer.feature_file.stem.replace('_', '-')
    
    def _get_feature_var_name(self) -> str:
        """Extract feature variable name (e.g., f_announce_items)."""
        # Look for pattern like: f_announce_items = {}
        match = re.search(r'^(\w+)\s*=\s*{}\s*$', self.analyzer.content, re.MULTILINE)
        if match:
            return match.group(1)
        # Fallback: try to find variable before BRC_FEATURE_NAME
        match = re.search(r'^(\w+)\s*=\s*{}\s*\n.*BRC_FEATURE_NAME', self.analyzer.content, re.MULTILINE | re.DOTALL)
        if match:
            return match.group(1)
        return "feature"  # Default fallback
    
    def generate(self) -> str:
        """Generate the standalone feature file."""
        parts = []
        
        # Header
        parts.append(self._generate_header())
        
        # Minimal BRC setup (only if needed)
        if self.analyzer.uses_config_emojis:
            parts.append(self._generate_brc_setup())
        else:
            parts.append("-- Minimal BRC namespace\nBRC = {}")
        
        # Constants (always include COL if using txt or mpr)
        if self.analyzer.used_constants or any("mpr" in m or "txt" in m for m in self.analyzer.used_modules):
            parts.append(self._generate_constants())
        
        # First pass: extract functions and detect cross-module dependencies
        # We need to do this before defining module tables to catch all dependencies
        all_modules = set(self.analyzer.used_modules)
        for module in sorted(self.analyzer.used_modules):
            if module in self.analyzer.used_functions and module != "BRC.Data":
                module_file = BRC_MODULES[module]
                module_content = self.extractor.read_file(module_file)
                func_names = self.analyzer.used_functions[module]
                _, additional_modules = self.extractor.extract_functions(
                    module_content, func_names, self.analyzer)
                all_modules.update(additional_modules)
        
        # Define all module tables first (so functions can reference each other)
        module_tables = []
        for module in sorted(all_modules):
            module_var = module.split('.')[1]
            module_tables.append(f"BRC.{module_var} = {{}}")
        if module_tables:
            parts.append("-- BRC module tables\n" + "\n".join(module_tables))
        
        # Module code (functions) - use all_modules to ensure we process everything
        for module in sorted(all_modules):
            parts.append(self._generate_module_code(module))
        
        # Feature code
        parts.append(self._generate_feature_code())
        
        # Hook wrappers (only if there are hooks other than init)
        hooks_content = self._generate_hooks()
        if hooks_content:
            parts.append(hooks_content)
        
        # Add init() call at the end
        parts.append(self._generate_init_call())
        
        content = '\n\n'.join(parts)
        
        # Post-process to fix closing braces (ensure they have comments or are merged)
        content = self._fix_closing_braces(content)
        
        return content
    
    def _generate_header(self) -> str:
        """Generate file header."""
        feature_file = self.analyzer.feature_file.relative_to(base_dir)
        return f"""## Standalone BRC Feature: {self.feature_name}
## Generated from: {feature_file}
## This file is self-contained and can be copy-pasted into your RC file.
## No external dependencies required.

{{
-- Standalone BRC Feature: {self.feature_name}"""
    
    def _generate_brc_setup(self) -> str:
        """Generate minimal BRC namespace setup."""
        return """-- Minimal BRC namespace
BRC = {}
BRC.Config = {
  emojis = false,
} -- BRC.Config"""
    
    def _generate_constants(self) -> str:
        """Generate needed constants, preserving comments on closing braces."""
        constants_content = self.extractor.read_file(BRC_CONSTANTS)
        result = ["-- BRC Constants"]
        
        # Always include COL if any color functions are used
        needs_col = any("mpr" in m or "txt" in m for m in self.analyzer.used_modules)
        if needs_col and "COL" not in self.analyzer.used_constants:
            self.analyzer.used_constants.add("COL")
        
        # Extract used constants
        for const in sorted(self.analyzer.used_constants):
            # Find the constant definition - handle multi-line
            # Try simple single-line first
            pattern = rf'BRC\.{re.escape(const)}\s*=\s*{{[^}}]*}}'
            match = re.search(pattern, constants_content)
            if not match:
                # Try multi-line with nested braces - need to find the closing brace with comment
                # Match from BRC.CONST = { to } -- comment
                pattern = rf'BRC\.{re.escape(const)}\s*=\s*{{.*?}}\s*--[^\n]*'
                match = re.search(pattern, constants_content, re.DOTALL)
            if not match:
                # Try without comment
                pattern = rf'BRC\.{re.escape(const)}\s*=\s*{{.*?}}'
                match = re.search(pattern, constants_content, re.DOTALL)
            if match:
                const_def = match.group(0)
                # Ensure closing brace has a comment if it's on its own line
                const_def = self._ensure_brace_comment(const_def)
                result.append(const_def)
        
        return '\n'.join(result)
    
    def _ensure_brace_comment(self, code: str) -> str:
        """Ensure closing braces have comments when on their own line."""
        lines = code.split('\n')
        result = []
        for i, line in enumerate(lines):
            stripped = line.strip()
            # If it's a closing brace on its own line without a comment
            if stripped == '}':
                # Check if next line has content (not just another closing brace)
                if i + 1 < len(lines) and lines[i + 1].strip() and not lines[i + 1].strip().startswith('}'):
                    # Add a comment
                    result.append('} -- end')
                else:
                    result.append(line)
            else:
                result.append(line)
        return '\n'.join(result)
    
    def _generate_module_code(self, module: str) -> str:
        """Generate code for a BRC module (functions only, table already defined)."""
        module_file = BRC_MODULES[module]
        module_content = self.extractor.read_file(module_file)
        
        result = [f"-- {module} module"]
        
        # Special handling for BRC.Data - use minimal version instead of extracting
        if module == "BRC.Data":
            # Create minimal persistence system for standalone features
            result.append(self._generate_minimal_persist())
        else:
            # Extract needed functions for other modules
            if module in self.analyzer.used_functions:
                func_names = self.analyzer.used_functions[module]
                extracted, additional_modules = self.extractor.extract_functions(
                    module_content, func_names, self.analyzer)
                # Add any cross-module dependencies we found
                for dep_module in additional_modules:
                    if dep_module not in self.analyzer.used_modules:
                        self.analyzer.used_modules.add(dep_module)
                        # Re-run generation would be complex, so we'll handle this in a second pass
                        # For now, just add the module table
                if extracted.strip():
                    result.append(extracted)
        
        if module == "BRC.txt":
            # Need to set up color functions if COL is available
            if "COL" in self.analyzer.used_constants or any("mpr" in m or "txt" in m for m in self.analyzer.used_modules):
                result.append(self._generate_txt_color_functions())
            # Also check if contains() is used (sets up string metatable)
            if "contains" in self.analyzer.used_functions.get(module, set()):
                result.append("-- Set up string:contains()\ngetmetatable(\"\").__index.contains = BRC.txt.contains")
        
        if module == "BRC.mpr":
            # Need to set up color functions if COL is available
            if "COL" in self.analyzer.used_constants or any("mpr" in m or "txt" in m for m in self.analyzer.used_modules):
                result.append(self._generate_mpr_color_functions())
            # Need mpr queue if que functions are used
            if any(f in self.analyzer.used_functions.get(module, set()) for f in ["que", "que_optmore", "consume_queue"]):
                result.append("-- Message queue for BRC.mpr\nlocal _mpr_queue = {}")
        
        return '\n'.join(result)
    
    def _generate_txt_color_functions(self) -> str:
        """Generate BRC.txt color functions."""
        return """-- BRC.txt color functions
for k, color in pairs(BRC.COL) do
  BRC.txt[k] = function(text)
    return string.format("<%s>%s</%s>", color, tostring(text), color)
  end
  BRC.txt[color] = BRC.txt[k]
end"""
    
    def _generate_mpr_color_functions(self) -> str:
        """Generate BRC.mpr color functions."""
        return """-- BRC.mpr color functions
for k, color in pairs(BRC.COL) do
  BRC.mpr[k] = function(msg, channel)
    crawl.mpr(BRC.txt[color](msg), channel)
    crawl.flush_prev_message()
  end
  BRC.mpr[color] = BRC.mpr[k]
end"""
    
    def _generate_minimal_persist(self) -> str:
        """Generate minimal persistence system for standalone features."""
        return """-- Minimal persistence system for standalone features
local _persist_names = {}
function BRC.Data.persist(name, default_value)
  -- If variable already exists (from chk_lua_save), use it
  -- Otherwise initialize from default
  if _G[name] == nil then
    if type(default_value) == "table" then
      _G[name] = {}
      for k, v in pairs(default_value) do
        _G[name][k] = v
      end
    else
      _G[name] = default_value
    end
  end
  
  -- Register for persistence (only once per variable)
  local already_registered = false
  for _, n in ipairs(_persist_names) do
    if n == name then
      already_registered = true
      break
    end
  end
  
  if not already_registered then
    _persist_names[#_persist_names + 1] = name
    table.insert(chk_lua_save, function()
      if _G[name] == nil then return "" end
      local val_str
      if type(_G[name]) == "table" then
        -- Simple table serialization (basic, but works for simple tables)
        local parts = {}
        for k, v in pairs(_G[name]) do
          if type(v) == "string" then
            table.insert(parts, string.format('[%s] = "%s"', tostring(k), v))
          else
            table.insert(parts, string.format('[%s] = %s', tostring(k), tostring(v)))
          end
        end
        val_str = "{" .. table.concat(parts, ", ") .. "}"
      else
        val_str = tostring(_G[name])
      end
      return name .. " = " .. val_str .. "\\n"
    end)
  end
  
  return _G[name]
end"""
    
    def _generate_feature_code(self) -> str:
        """Generate the feature code itself, preserving comments on closing braces."""
        # Remove BRC_FEATURE_NAME line (not needed in standalone)
        content = re.sub(r'^\s*\w+\.BRC_FEATURE_NAME\s*=.*$', '', 
                        self.analyzer.content, flags=re.MULTILINE)
        
        # Remove disabled = true from Config if present (standalone is always active)
        content = re.sub(r'(\s+disabled\s*=\s*)true', r'\1false', content)
        
        # Ensure closing braces have comments
        content = self._ensure_brace_comment(content)
        
        return f"-- Feature code\n{content}"
    
    def _generate_hooks(self) -> str:
        """Generate crawl hook wrappers (excluding init, which is called directly)."""
        feature_var = self.feature_var
        hooks_to_generate = []
        
        # Collect hooks to generate (skip init since we call it directly at the end)
        for hook in sorted(self.analyzer.used_hooks):
            if hook == "init":
                continue
            hooks_to_generate.append(hook)
        
        # Only generate if there are hooks
        if not hooks_to_generate:
            return ""
        
        result = ["-- Crawl hook wrappers"]
        for hook in hooks_to_generate:
            crawl_hook = CRAWL_HOOKS[hook]
            result.append(f"""function {crawl_hook}(...)
  if {feature_var}.{hook} then
    return {feature_var}.{hook}(...)
  end
end""")
        
        return '\n'.join(result)
    
    def _generate_init_call(self) -> str:
        """Generate init() call at the end of the lua block."""
        feature_var = self.feature_var
        return f"-- Initialize feature\n{feature_var}.init()"
    
    def _generate_footer(self) -> str:
        """Generate file footer."""
        return "}"
    
    def _fix_closing_braces(self, content: str) -> str:
        """Fix closing braces to ensure they're never on a line by themselves (except at the very end)."""
        lines = content.split('\n')
        result = []
        
        for i, line in enumerate(lines):
            stripped = line.strip()
            
            # Check if this is a closing brace on its own line
            if stripped == '}':
                # Standalone closing brace without comment - need to fix
                # Check if this is the very last brace (before footer comment)
                is_last_brace = False
                for j in range(i + 1, len(lines)):
                    next_line = lines[j].strip()
                    if next_line and not next_line.startswith('--'):
                        break
                    if next_line.startswith('} --'):
                        is_last_brace = True
                        break
                
                if is_last_brace:
                    # This is the final closing brace - it's OK
                    result.append(line)
                else:
                    # Not the last brace - need to add a comment
                    # Preserve indentation
                    indent = len(line) - len(line.lstrip())
                    result.append(' ' * indent + '} -- end')
            elif stripped.startswith('} --'):
                # Already has a comment - keep as is
                result.append(line)
            else:
                result.append(line)
        
        return '\n'.join(result)

def main():
    """Main entry point."""
    for feature_path in features_dir.glob("*.lua"):
        print(f"Analyzing feature: {feature_path.name}")
        
        # Analyze dependencies
        analyzer = DependencyAnalyzer(feature_path)
        analyzer.analyze()
        
        print(f"  Dependencies found:")
        print(f"    Modules: {sorted(analyzer.used_modules)}")
        print(f"    Hooks: {sorted(analyzer.used_hooks)}")
        print(f"    Constants: {sorted(analyzer.used_constants)}")
        
        # Generate standalone file
        extractor = CodeExtractor()
        generator = StandaloneGenerator(analyzer, extractor)
        standalone_content = generator.generate()
        
        # Add footer
        standalone_content += "\n\n" + generator._generate_footer()
        
        # Write output
        output_file = output_dir / f"{generator.feature_name}.rc"
        output_file.write_text(standalone_content, encoding='utf-8')
        
        print(f"\nGenerated: {output_file}")
        print(f"  Size: {len(standalone_content)} characters, {len(standalone_content.splitlines())} lines")
        print()  # Blank line between features

if __name__ == "__main__":
    main()
