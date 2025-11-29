#!/usr/bin/env python3
"""
Standalone Feature Generator for BRC

Generates standalone feature files that can be copy-pasted into RC files
without requiring the full BRC core. Features are always active and called
directly from crawl's hooks.
"""

import re
from pathlib import Path
from typing import Set, Dict, List, Tuple, Optional

# ============================================================================
# Configuration
# ============================================================================

base_dir = Path(__file__).parent.parent
core_dir = base_dir / "lua" / "core"
util_dir = base_dir / "lua" / "util"
features_dir = base_dir / "lua" / "features"
output_dir = base_dir / "bin" / "standalone_features"
output_dir.mkdir(parents=True, exist_ok=True)

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
    "BRC.Configs": core_dir / "config.lua",
}

BRC_CONSTANTS = core_dir / "constants.lua"
BRC_HEADER = core_dir / "_header.lua"

CRAWL_HOOKS = ["ready", "autopickup", "c_answer_prompt", "c_assign_invletter", "c_message", "ch_start_running"]

# ============================================================================
# File Caching
# ============================================================================

_file_content_cache: Dict[Path, List[str]] = {}
_file_text_cache: Dict[Path, str] = {}

def _get_cached_lines(file_path: Path) -> List[str]:
    """Get file lines from cache, loading if necessary."""
    if file_path not in _file_content_cache:
        _file_content_cache[file_path] = file_path.read_text(encoding='utf-8').split('\n')
    return _file_content_cache[file_path]

def _get_cached_text(file_path: Path) -> str:
    """Get file text from cache, loading if necessary."""
    if file_path not in _file_text_cache:
        _file_text_cache[file_path] = file_path.read_text(encoding='utf-8')
    return _file_text_cache[file_path]

# ============================================================================
# Constants Extraction
# ============================================================================

def get_constant_names() -> List[str]:
    """Extract all constant names from constants.lua."""
    content = _get_cached_text(BRC_CONSTANTS)
    matches = re.findall(r'BRC\.(\w+)\s*=', content)
    return [m for m in matches if m not in ['Config', 'Configs']]

def get_config_emojis_default() -> bool:
    """Extract the default emojis value from _header.lua."""
    content = _get_cached_text(BRC_HEADER)
    match = re.search(r'emojis\s*=\s*(true|false)', content)
    return match.group(1) == 'true' if match else False

def match_constant_definition(content: str, const_name: str) -> Optional[str]:
    """Match a constant definition with balanced braces."""
    pattern = rf'BRC\.{re.escape(const_name)}\s*=\s*\{{'
    match = re.search(pattern, content)
    if not match:
        return None
    
    # Match balanced braces
    start_pos = match.end() - 1
    depth = 0
    for i in range(start_pos, len(content)):
        if content[i] == '{':
            depth += 1
        elif content[i] == '}':
            depth -= 1
            if depth == 0:
                end_pos = i + 1
                # Include trailing comment if present
                remaining = content[end_pos:end_pos + 200]
                comment_match = re.search(r'\s*--[^\n]*', remaining)
                return content[match.start():end_pos + (comment_match.end() if comment_match else 0)]
    return None

# ============================================================================
# Code Extraction Utilities
# ============================================================================

def _extract_function_block(lines: List[str], start_idx: int) -> List[str]:
    """Extract a complete function block from start_idx to its matching 'end'."""
    result = [lines[start_idx]]
    initial_indent = len(lines[start_idx]) - len(lines[start_idx].lstrip())
    i = start_idx + 1
    
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            result.append(line)
            i += 1
            continue
        
        current_indent = len(line) - len(line.lstrip())
        if current_indent <= initial_indent and line.strip() and not line.strip().startswith('--'):
            if line.strip() == 'end' and current_indent == initial_indent:
                result.append(line)
            break
        result.append(line)
        i += 1
    return result

def _find_function_by_pattern(lines: List[str], pattern: re.Pattern, start_idx: int = 0) -> Optional[Tuple[int, str]]:
    """Find a function matching the pattern. Returns (line_index, function_name) or None."""
    for i in range(start_idx, len(lines)):
        match = pattern.match(lines[i].strip())
        if match:
            func_name = match.group(1) if match.lastindex else None
            return (i, func_name)
    return None

def extract_lua_function(module_name: str, function_name: str) -> Optional[str]:
    """Extract a specific BRC module function from a file."""
    lines = _get_cached_lines(BRC_MODULES[module_name])
    module_var = module_name.split('.')[1]
    pattern = re.compile(rf'^function\s+BRC\.{re.escape(module_var)}\.{re.escape(function_name)}\s*\(')
    
    result = _find_function_by_pattern(lines, pattern)
    if result:
        func_lines = _extract_function_block(lines, result[0])
        return '\n'.join(func_lines)
    return None

def extract_local_functions(file_path: Path) -> Dict[str, str]:
    """Extract all local functions from a file."""
    lines = _get_cached_lines(file_path)
    result = {}
    pattern = re.compile(r'^local\s+function\s+(\w+)\s*\(')
    
    i = 0
    while i < len(lines):
        match = _find_function_by_pattern(lines, pattern, i)
        if match:
            line_idx, func_name = match
            func_lines = _extract_function_block(lines, line_idx)
            result[func_name] = '\n'.join(func_lines)
            i = line_idx + len(func_lines)
        else:
            i += 1
    return result

def extract_init_code(file_path: Path) -> str:
    """Extract all top-level (non-function) code, excluding comments and empty lines."""
    lines = _get_cached_lines(file_path)
    result = []
    in_function = False
    function_indent = 0
    
    for i, line in enumerate(lines):
        stripped = line.strip()
        
        # Skip empty lines, comments, and _mpr_queue/_single_turn_mutes declaration
        if (not stripped or stripped.startswith('--') or
            stripped in ["local _mpr_queue = {}", "local _single_turn_mutes = {}"]):
            continue
        
        current_indent = len(line) - len(line.lstrip())
        
        # Track function boundaries
        if not in_function and re.match(r'^(local\s+)?function\s+', stripped):
            in_function = True
            function_indent = current_indent
            continue
        
        if in_function:
            if stripped == 'end' and current_indent <= function_indent:
                in_function = False
                function_indent = 0
            continue

        # Top-level code (not in function, not module table declaration)
        if not re.match(r'^BRC\.\w+\s*=\s*\{\}\s*$', stripped):
            result.append(line)
    
    return '\n'.join(result).strip()

# ============================================================================
# Dependency Analysis
# ============================================================================

class DependencyAnalyzer:
    """Analyzes feature files to recursively find all BRC dependencies."""
    
    def __init__(self, feature_file: Path):
        self.feature_file = feature_file
        self.content = feature_file.read_text(encoding='utf-8')
        self.used_modules: Set[str] = set()
        self.used_functions: Dict[str, Set[str]] = {}
        self.used_constants: Set[str] = set()
        self.used_hooks: Set[str] = set()
        self.uses_persist = False
        self.uses_config = False
        self.extracted_functions: Dict[Tuple[str, str], str] = {}
        self.init_code_blocks: Dict[str, List[str]] = {}
        self.local_functions: Dict[str, Dict[str, str]] = {}
    
    def analyze(self):
        """Perform complete dependency analysis."""
        self._find_brc_references(self.content)
        self._extract_dependencies_recursively()
        self._extract_init_blocks()
        self._extract_dependencies_recursively()  # Check init blocks for dependencies
        self._extract_local_functions()
    
    def _extract_dependencies_recursively(self):
        """Recursively extract dependencies until no new ones are found."""
        changed = True
        while changed:
            changed = False
            new_functions = {}
            
            # Check all extracted code for new BRC references
            sources = list(self.extracted_functions.values())
            sources.extend([block for blocks in self.init_code_blocks.values() for block in blocks])
            
            for code in sources:
                new_refs = self._find_brc_references(code)
                for mod, funcs in new_refs.items():
                    for func in funcs:
                        if (mod, func) not in self.extracted_functions:
                            changed = True
                            if func_code := extract_lua_function(mod, func):
                                new_functions[(mod, func)] = func_code
            
            self.extracted_functions.update(new_functions)
    
    def _find_brc_references(self, content: str) -> Dict[str, Set[str]]:
        """Find all BRC references in content. Returns dict of module -> set of NEW function names."""
        new_refs: Dict[str, Set[str]] = {}
        
        # Find module function references
        for module in BRC_MODULES.keys():
            if re.search(rf'\b{re.escape(module)}\b', content):
                self.used_modules.add(module)
                matches = re.findall(rf'\b{re.escape(module)}\.(\w+)', content)
                if matches:
                    self.used_functions.setdefault(module, set())
                    for match in matches:
                        if match not in self.used_functions[module]:
                            self.used_functions[module].add(match)
                            new_refs.setdefault(module, set()).add(match)
                            if (module, match) not in self.extracted_functions:
                                if func_code := extract_lua_function(module, match):
                                    self.extracted_functions[(module, match)] = func_code
        
        # Find constants
        for const in get_constant_names():
            if re.search(rf'\bBRC\.{const}\b', content):
                self.used_constants.add(const)
        
        # Find special cases
        if re.search(r'\bBRC\.Data\.persist\b', content):
            self.uses_persist = True
            self.used_modules.add("BRC.Data")
        if re.search(r'\.Config\b', content):
            self.uses_config = True
        
        # Find hooks
        for hook_name in CRAWL_HOOKS:
            if re.search(rf'function\s+\w+\.{hook_name}\s*\(', content):
                self.used_hooks.add(hook_name)
        if content is self.content and re.search(r'function\s+\w+\.init\s*\(', content):
            self.used_hooks.add("init")
        
        return new_refs
    
    def _extract_init_blocks(self):
        """Extract top-level initialization code from used modules."""
        for module in list(self.used_modules):
            if module == "BRC.Data":
                continue
            init_code = extract_init_code(BRC_MODULES[module])
            if init_code:
                self.init_code_blocks[module] = [init_code]
                self._find_brc_references(init_code)
    
    def _extract_local_functions(self):
        """Extract local functions called by extracted module functions."""
        for module in self.used_modules:
            if module == "BRC.Data":
                continue
            
            all_local_funcs = extract_local_functions(BRC_MODULES[module])
            called_local_funcs = set()
            
            for (mod, func_name), func_code in self.extracted_functions.items():
                if mod == module:
                    for local_func_name in all_local_funcs.keys():
                        if re.search(rf'\b{re.escape(local_func_name)}\s*\(', func_code):
                            called_local_funcs.add(local_func_name)
            
            if called_local_funcs:
                self.local_functions[module] = {
                    name: all_local_funcs[name] for name in called_local_funcs
                }

# ============================================================================
# Code Generation
# ============================================================================

class StandaloneGenerator:
    """Generates standalone feature files with all dependencies included."""
    
    def __init__(self, analyzer: DependencyAnalyzer):
        self.analyzer = analyzer
        self.feature_name = self._get_feature_name()
        self.feature_var = self._get_feature_var_name()
    
    def _get_feature_name(self) -> str:
        """Extract feature name from BRC_FEATURE_NAME or derive from filename."""
        match = re.search(r'BRC_FEATURE_NAME\s*=\s*["\']([^"\']+)["\']', self.analyzer.content)
        return match.group(1) if match else self.analyzer.feature_file.stem.replace('_', '-')
    
    def _get_feature_var_name(self) -> str:
        """Extract feature variable name from code."""
        for pattern in [r'^(\w+)\s*=\s*{}\s*$', r'^(\w+)\s*=\s*{}\s*\n.*BRC_FEATURE_NAME']:
            match = re.search(pattern, self.analyzer.content, re.MULTILINE | re.DOTALL)
            if match:
                return match.group(1)
        return "feature"
    
    def _needs_consume_queue(self) -> bool:
        """Check if the generated content uses the mpr queue."""
        all_code = self.analyzer.content
        for func_code in self.analyzer.extracted_functions.values():
            all_code += func_code
        for blocks in self.analyzer.init_code_blocks.values():
            for block in blocks:
                all_code += block
        for module_local_funcs in self.analyzer.local_functions.values():
            for local_func_code in module_local_funcs.values():
                all_code += local_func_code
        return 'BRC.mpr.que' in all_code
    
    def _needs_single_turn_mutes(self) -> bool:
        """Check if the generated content uses single turn mutes."""
        all_code = self.analyzer.content
        for func_code in self.analyzer.extracted_functions.values():
            all_code += func_code
        for blocks in self.analyzer.init_code_blocks.values():
            for block in blocks:
                all_code += block
        return 'BRC.opt.single_turn_mute' in all_code

    def generate(self) -> str:
        """Generate complete standalone feature file."""
        parts = [
            self._generate_header(),
            self._generate_brc_setup(),
        ]
        
        # Add COL constant if using color functions
        if any("mpr" in m or "txt" in m for m in self.analyzer.used_modules):
            self.analyzer.used_constants.add("COL")
        
        if self.analyzer.used_constants:
            parts.append(self._generate_constants())
        
        module_tables = [f"BRC.{m.split('.')[1]} = {{}}" for m in sorted(self.analyzer.used_modules)]
        if module_tables:
            parts.append("-- BRC module tables\n" + "\n".join(module_tables))
        
        for module in sorted(self.analyzer.used_modules):
            parts.append(self._generate_module_code(module))
        
        if self._needs_consume_queue():
            parts.append(self._generate_consume_queue())
        
        if self._needs_single_turn_mutes():
            parts.append(self._generate_single_turn_mutes())
        
        parts.extend([
            self._generate_feature_code(),
            self._generate_hooks(),
            self._generate_init_call(),
        ])
        
        return '\n\n'.join(filter(None, parts))
    
    def _generate_header(self) -> str:
        """Generate file header with metadata."""
        feature_file = self.analyzer.feature_file.relative_to(base_dir)
        return "\n".join([
            f"## Standalone BRC Feature: {self.feature_name}",
            f"## Generated from: {feature_file}",
            "## This file is self-contained and can be copy-pasted into your RC file.",
            "## No external dependencies required.",
            "",
            "{",
        ])
    
    def _generate_brc_setup(self) -> str:
        """Generate minimal BRC namespace setup."""
        emojis = 'true' if get_config_emojis_default() else 'false'
        return f"-- Minimal BRC namespace\nBRC = {{ Config = {{ emojis = {emojis} }} }}"
    
    def _generate_constants(self) -> str:
        """Generate needed constants with balanced brace matching."""
        constants_content = _get_cached_text(BRC_CONSTANTS)
        result = ["-- BRC Constants"]
        added = set()
        
        for const in sorted(self.analyzer.used_constants):
            if const not in added:
                matched = match_constant_definition(constants_content, const)
                if matched:
                    result.extend([matched, ''])
                    added.add(const)
        
        return '\n'.join(result)
    
    def _generate_module_code(self, module: str) -> str:
        """Generate code for a BRC module."""
        result = [f"-- {module} module"]
        
        if module == "BRC.Data":
            result.append(self._generate_minimal_persist())
        else:
            if module in self.analyzer.init_code_blocks:
                for block in self.analyzer.init_code_blocks[module]:
                    result.append(block)
                result.append('')
            
            if module in self.analyzer.local_functions:
                for func_name in sorted(self.analyzer.local_functions[module].keys()):
                    result.append(self.analyzer.local_functions[module][func_name])
                    result.append('')
            
            if module in self.analyzer.used_functions:
                func_names = sorted(self.analyzer.used_functions[module])
                extracted_funcs = [
                    self.analyzer.extracted_functions[(module, name)]
                    for name in func_names
                    if (module, name) in self.analyzer.extracted_functions
                ]
                if extracted_funcs:
                    result.append('\n\n'.join(extracted_funcs))
        
        return '\n'.join(result)
    
    def _generate_minimal_persist(self) -> str:
        """Generate minimal persistence system for standalone features."""
        return "\n".join([
            "-- Minimal persistence system for standalone features",
            "local _persist_names = {}",
            "function BRC.Data.persist(name, default_value)",
            "  -- If variable already exists (from chk_lua_save), use it",
            "  -- Otherwise initialize from default",
            "  if _G[name] == nil then",
            "    if type(default_value) == \"table\" then",
            "      _G[name] = {}",
            "      for k, v in pairs(default_value) do",
            "        _G[name][k] = v",
            "      end",
            "    else",
            "      _G[name] = default_value",
            "    end",
            "  end",
            "",
            "  _persist_names[#_persist_names + 1] = name",
            "  table.insert(chk_lua_save, function()",
            "    if _G[name] == nil then return \"\" end",
            "    local val_str",
            "    if type(_G[name]) == \"table\" then",
            "      -- Simple table serialization (basic, but works for simple tables)",
            "      local parts = {}",
            "      for k, v in pairs(_G[name]) do",
            "        if type(v) == \"string\" then",
            "          table.insert(parts, string.format('[%s] = \"%s\"', tostring(k), v))",
            "        else",
            "          table.insert(parts, string.format('[%s] = %s', tostring(k), tostring(v)))",
            "        end",
            "      end",
            "      val_str = \"{\" .. table.concat(parts, \", \") .. \"}\"",
            "    else",
            "      val_str = tostring(_G[name])",
            "    end",
            "  return name .. \" = \" .. val_str .. \"\\\\n\"",
            "  end)",
            "",
            "  return _G[name]",
            "end",
        ])
    
    def _generate_feature_code(self) -> str:
        """Generate the feature code itself."""
        content = re.sub(r'^\s*\w+\.BRC_FEATURE_NAME\s*=.*$', '', 
                        self.analyzer.content, flags=re.MULTILINE)
        content = re.sub(r'(\s+disabled\s*=\s*)true', r'\1false', content)
        return f"-- Feature code\n{content}"
    
    def _generate_hooks(self) -> str:
        """Generate crawl hook wrappers (excluding init)."""
        hooks = [h for h in sorted(self.analyzer.used_hooks) if h != "init"]
        
        # Ensure ready() exists if using mpr queue
        needs_consume = self._needs_consume_queue()
        needs_mutes = self._needs_single_turn_mutes()
        if "ready" not in hooks and (needs_consume or needs_mutes):
            hooks.append("ready")
            hooks = sorted(hooks)
        
        if not hooks:
            return ""
        
        result = ["-- Crawl hook wrappers"]
        for hook in hooks:
            if hook == "ready":
                hook_code = "\n".join([
                    f"local brc_last_turn = -1",
                    f"function {hook}(...)",
                    *([f"  BRC.opt.clear_single_turn_mutes()"] if needs_mutes else []),
                    f"  if you.turns() > brc_last_turn then",
                    f"    brc_last_turn = you.turns()",
                    f"    {self.feature_var}.{hook}(...)",
                    f"  end",
                    *([f"  BRC.mpr.consume_queue()"] if needs_consume else []),
                    f"end",
                ])
                result.append(hook_code)
            elif hook == "autopickup":
                result.append(f"add_autopickup_func({self.feature_var}.autopickup)")
            else:
                result.append(f"function {hook}(...)\n  return {self.feature_var}.{hook}(...)\nend")
            result.append('')
        return '\n'.join(result)
    
    def _generate_consume_queue(self) -> str:
        return "\n".join([
            "-- mpr queue support: _mpr_queue and BRC.mpr.consume_queue()",
            "_mpr_queue = {}",
            extract_lua_function("BRC.mpr", "consume_queue"),
        ])
    
    def _generate_single_turn_mutes(self) -> str:
        return "\n".join([
            "-- single turn mutes support: _single_turn_mutes and BRC.opt.clear_single_turn_mutes()",
            "_single_turn_mutes = {}",
            extract_lua_function("BRC.opt", "clear_single_turn_mutes"),
        ])
    
    def _generate_init_call(self) -> str:
        return f"-- Initialize feature\n{self.feature_var}.init()"

# ============================================================================
# Main Entry Point
# ============================================================================

def main():
    """Process all feature files and generate standalone versions."""
    for feature_path in features_dir.glob("*.lua"):
        if "_template" in feature_path.name:
            continue

        print(f"Analyzing feature: {feature_path.name}")
        
        analyzer = DependencyAnalyzer(feature_path)
        analyzer.analyze()
        
        print(f"  Dependencies found:")
        print(f"    Modules: {sorted(analyzer.used_modules)}")
        print(f"    Hooks: {sorted(analyzer.used_hooks)}")
        print(f"    Constants: {sorted(analyzer.used_constants)}")
        
        generator = StandaloneGenerator(analyzer)
        standalone_content = generator.generate()
        standalone_content += "\n\n}\n"

        output_file = output_dir / f"{generator.feature_name}.rc"
        output_file.write_text(standalone_content, encoding='utf-8')
        
        print(f"\nGenerated: {output_file}")
        print(f"  Size: {len(standalone_content)} characters, {len(standalone_content.splitlines())} lines")
        print()

if __name__ == "__main__":
    main()
