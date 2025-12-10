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
    "BRC.Configs": core_dir / "config.lua",
}

BRC_CONSTANTS = core_dir / "constants.lua"
BRC_HEADER = core_dir / "_header.lua"

CRAWL_HOOKS = ["ready", "autopickup", "c_answer_prompt", "c_assign_invletter", "c_message", "ch_start_running"]

# ============================================================================
# File Caching
# ============================================================================

_file_cache: Dict[Path, str] = {}

def _get_cached_text(file_path: Path) -> str:
    if file_path not in _file_cache:
        _file_cache[file_path] = file_path.read_text(encoding='utf-8')
    return _file_cache[file_path]

def _get_cached_lines(file_path: Path) -> List[str]:
    return _get_cached_text(file_path).split('\n')


# ============================================================================
# Constants Extraction
# ============================================================================

def get_constant_names() -> List[str]:
    content = _get_cached_text(BRC_CONSTANTS)
    return [m for m in re.findall(r'BRC\.(\w+)\s*=', content) if m not in ['Config', 'Configs']]

def get_default_config_boolean(pattern: str) -> str:
    content = _get_cached_text(BRC_HEADER)
    match = re.search(rf'{pattern}\s*=\s*(true|false)', content)
    return match.group(1) if match else "false"

def match_constant_definition(content: str, const_name: str) -> Optional[str]:
    pattern = rf'BRC\.{re.escape(const_name)}\s*=\s*\{{'
    match = re.search(pattern, content)
    if not match:
        return None
    
    start_pos = match.end() - 1
    depth = 1
    for i in range(start_pos + 1, len(content)):
        if content[i] == '{':
            depth += 1
        elif content[i] == '}':
            depth -= 1
            if depth == 0:
                end_pos = i + 1
                next_newline = content.find('\n', end_pos)
                if next_newline == -1:
                    next_newline = len(content)
                remaining = content[end_pos:next_newline]
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
    lines = _get_cached_lines(BRC_MODULES[module_name])
    module_var = module_name.split('.')[1]
    pattern = re.compile(rf'^function\s+BRC\.{re.escape(module_var)}\.{re.escape(function_name)}\s*\(')
    result = _find_function_by_pattern(lines, pattern)
    if result:
        return '\n'.join(_extract_function_block(lines, result[0]))
    return None

def extract_local_functions(file_path: Path) -> Dict[str, str]:
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

def extract_top_level(file_path: Path) -> str:
    lines = _get_cached_lines(file_path)
    result = []
    in_function = False
    function_indent = 0
    skip_patterns = {"local _mpr_queue = {}", "local _single_turn_mutes = {}", 
                     'getmetatable("").__index.contains = BRC.txt.contains'}
    
    for i, line in enumerate(lines):
        stripped = line.strip()
        if (not stripped or stripped.startswith('--') or stripped in skip_patterns):
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

        if not re.match(r'^BRC\.\w+\s*=\s*\{\}\s*$', stripped):
            result.append(line)
    
    return '\n'.join(result).strip()

def get_txt_contains_code() -> str:
    return "\n".join([
        "-- define string:contains() for all strings",
        "function BRC_txt_str_contains(self, text)",
        "  return self:find(text, 1, true) ~= nil",
        "end",
        'getmetatable("").__index.contains = BRC_txt_str_contains',
    ])


def get_minimal_persist_code() -> str:
    return "\n".join([
        'local function brc_tostr(value)',
        '  if type(value) == "table" then',
        '    if #value == 0 then',
        '      local result = "{ "',
        '      for k, v in pairs(value) do',
        '        result = result .. k .. " = " .. brc_tostr(v) .. ", "',
        '      end',
        '      return result .. " }"',
        '    else',
        '      return "{ " .. table.concat(value, ", ") .. " }"',
        '    end',
        '  elseif type(value) == "string" then',
        '    return "\\"" .. value:gsub("\\"", "") .. "\\""',
        '  else',
        '    return tostring(value)',
        '  end',
        'end',
        '',
        'function BRC.Data.persist(name, default_value)',
        '  if _G[name] == nil then',
        '    if type(default_value) == "table" then',
        '      _G[name] = util.copy_table(default_value)',
        '    else',
        '      _G[name] = default_value',
        '    end',
        '  end',
        '  table.insert(chk_lua_save, function()',
        '    if _G[name] == nil then return "" end',
        '    return name .. " = " .. brc_tostr(_G[name]) .. "\\n"',
        '  end)',
        '  return _G[name]',
        'end',
    ])

# ============================================================================
# Dependency Analysis
# ============================================================================

class DependencyAnalyzer:
    """Analyzes feature files to recursively find all BRC dependencies."""
    
    def __init__(self, feature_file: Path, content: Optional[str] = None):
        self.feature_file = feature_file
        self.content = content if content is not None else feature_file.read_text(encoding='utf-8')
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
        
        changed = True
        while changed:
            changed = self._extract_dependencies_recursively()

            prev_modules = len(self.used_modules)
            self._extract_top_level()
            if len(self.used_modules) > prev_modules:
                changed = True

            prev_local_funcs = sum(len(funcs) for funcs in self.local_functions.values())
            self._extract_local_functions()
            if sum(len(funcs) for funcs in self.local_functions.values()) > prev_local_funcs:
                changed = True

    def get_all_code(self) -> str:
        """Get all code from the feature file and its dependencies."""
        return "\n".join([self.content] +
            [func_code for func_code in self.extracted_functions.values()] +
            [block for blocks in self.init_code_blocks.values() for block in blocks] +
            [local_func_code for module_local_funcs in self.local_functions.values()
                for local_func_code in module_local_funcs.values()])

    def _extract_dependencies_recursively(self) -> bool:
        """Extract dependencies from all current code. Returns True if new dependencies were found."""
        changed = False
        new_functions = {}

        sources = [code for code in self.extracted_functions.values() if code is not None]
        sources.extend([block for blocks in self.init_code_blocks.values() for block in blocks])
        sources.extend([func_code for module_funcs in self.local_functions.values() 
                        for func_code in module_funcs.values()])
        
        if self.uses_persist:
            sources.append(get_minimal_persist_code())
        
        for code in sources:
            if code is None:
                continue
            new_refs = self._find_brc_references(code)
            for mod, funcs in new_refs.items():
                for func in funcs:
                    if (mod, func) not in self.extracted_functions:
                        changed = True
                        if func_code := extract_lua_function(mod, func):
                            new_functions[(mod, func)] = func_code
                            self._find_brc_references(func_code)
        
        self.extracted_functions.update(new_functions)
        return changed
    
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
                                if module == "BRC.Data" and match == "persist":
                                    func_code = get_minimal_persist_code()
                                else:
                                    func_code = extract_lua_function(module, match)
                                if func_code:
                                    self.extracted_functions[(module, match)] = func_code
                                    self._find_brc_references(func_code)
        
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
    
    def _extract_top_level(self):
        for module in list(self.used_modules):
            if module in ["BRC.Data", "BRC.Hotkey", "BRC.Configs"]:
                continue
            init_code = extract_top_level(BRC_MODULES[module])
            if init_code:
                self.init_code_blocks[module] = [init_code]
                self._find_brc_references(init_code)
    
    def _extract_local_functions(self):
        for module in list(self.used_modules):
            if module in ["BRC.Data", "BRC.Hotkey", "BRC.Configs"]:
                continue
            
            all_local_funcs = extract_local_functions(BRC_MODULES[module])
            if not all_local_funcs:
                continue
            
            # Start with local functions called by extracted module functions
            called_local_funcs = set()
            for (mod, func_name), func_code in self.extracted_functions.items():
                if mod == module:
                    for local_func_name in all_local_funcs.keys():
                        if re.search(rf'\b{re.escape(local_func_name)}\s*\(', func_code):
                            called_local_funcs.add(local_func_name)
            
            # Recursively find local functions called by other local functions
            changed = True
            while changed:
                changed = False
                for local_func_name in list(called_local_funcs):
                    local_func_code = all_local_funcs[local_func_name]
                    for other_local_func_name in all_local_funcs.keys():
                        if other_local_func_name not in called_local_funcs:
                            if re.search(rf'\b{re.escape(other_local_func_name)}\s*\(', local_func_code):
                                called_local_funcs.add(other_local_func_name)
                                changed = True
            
            if called_local_funcs:
                local_funcs_dict = {name: all_local_funcs[name] for name in called_local_funcs}
                ordered_funcs = self._topological_sort_local_functions(local_funcs_dict, all_local_funcs)
                self.local_functions[module] = {name: local_funcs_dict[name] for name in ordered_funcs}
                for local_func_code in local_funcs_dict.values():
                    self._find_brc_references(local_func_code)
    
    def _topological_sort_local_functions(
        self, local_funcs: Dict[str, str], all_local_funcs: Dict[str, str]
    ) -> List[str]:
        dependents: Dict[str, Set[str]] = {name: set() for name in local_funcs.keys()}
        in_degree: Dict[str, int] = {name: 0 for name in local_funcs.keys()}
        
        for func_name, func_code in local_funcs.items():
            for other_func_name in all_local_funcs.keys():
                if other_func_name != func_name and other_func_name in local_funcs:
                    if re.search(rf'\b{re.escape(other_func_name)}\s*\(', func_code):
                        dependents[other_func_name].add(func_name)
                        # Calculate in-degree: how many dependencies each function has
                        in_degree[func_name] += 1
        
        # Start with functions that have no dependencies (in-degree 0)
        queue = [name for name, degree in in_degree.items() if degree == 0]
        result = []
        while queue:
            # Sort queue for deterministic output
            queue.sort()
            func_name = queue.pop(0)
            result.append(func_name)
            
            # Decrease in-degree for functions that depend on this one
            for dependent in dependents[func_name]:
                in_degree[dependent] -= 1
                if in_degree[dependent] == 0:
                    queue.append(dependent)
        
        # If we didn't process all functions, there's a cycle (shouldn't happen in valid code)
        # But include remaining functions anyway
        remaining = set(local_funcs.keys()) - set(result)
        if remaining:
            result.extend(sorted(remaining))
        
        return result
    
# ============================================================================
# Code Generation
# ============================================================================

class StandaloneGenerator:
    """Generates standalone feature files with all dependencies included."""
    
    def __init__(self, analyzer: DependencyAnalyzer, f_var_name: Optional[str] = None):
        self.analyzer = analyzer
        self.feature_name = self._get_feature_name()
        self.feature_var = f_var_name if f_var_name else self._get_feature_var_name()
    
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
        return 'BRC.mpr.que' in self.analyzer.get_all_code()
    
    def _needs_debug(self) -> bool:
        return 'BRC.Config.mpr.show_debug_messages' in self.analyzer.get_all_code()
    
    def _needs_stderr(self) -> bool:
        return 'BRC.Config.mpr.logs_to_stderr' in self.analyzer.get_all_code()

    def _needs_single_turn_mutes(self) -> bool:
        return 'BRC.opt.single_turn_mute' in self.analyzer.get_all_code()
    
    def _needs_txt_contains(self) -> bool:
        return ':contains' in self.analyzer.get_all_code()
    
    def _find_config_section_bounds(self, lines: List[str]) -> Optional[Tuple[int, int]]:
        config_pattern = re.compile(rf'^{re.escape(self.feature_var)}\.Config(\.\w+)*\s*=')
        start_idx = next((i for i, line in enumerate(lines) if config_pattern.match(line.strip())), None)
        if start_idx is None:
            return None
        
        i = start_idx
        in_multiline_string = False
        while i < len(lines):
            stripped = lines[i].strip()
            if not config_pattern.match(stripped):
                break

            brace_count = stripped.count('{') - stripped.count('}')
            in_multiline_string = bool(re.search(r'=\s+\[\[', stripped))
            i += 1
            
            while i < len(lines) and (brace_count > 0 or in_multiline_string):
                stripped = lines[i].strip()
                brace_count += stripped.count('{') - stripped.count('}')
                if re.search(r'=\s+\[\[', stripped):
                    in_multiline_string = True
                if in_multiline_string and re.match(r'^\-*\s*\]\]', stripped):
                    in_multiline_string = False
                i += 1

            while i < len(lines):
                stripped = lines[i].strip()
                if not stripped or stripped.startswith('--') or in_multiline_string:
                    i += 1
                    if re.search(r'\[\[', stripped):
                        in_multiline_string = True
                    if in_multiline_string and re.match(r'^\-*\s*\]\]', stripped):
                        in_multiline_string = False
                else:
                    break

        i -= 1
        while i > start_idx:
            stripped = lines[i].strip()
            if not stripped or (stripped.startswith('--') and "config" not in stripped):
                i -= 1
            else:
                break
        
        return (start_idx, i+1)
    
    def _extract_config_section(self) -> Optional[str]:
        lines = self.analyzer.content.split('\n')
        bounds = self._find_config_section_bounds(lines)
        return '\n'.join(lines[bounds[0]:bounds[1]]) if bounds else None

    def generate(self) -> str:
        parts = [
            self._generate_header(),
            self._generate_brc_setup(),
            self._generate_config_section(),
            get_txt_contains_code() if self._needs_txt_contains() else None,
        ]

        if any("mpr" in m or "txt" in m for m in self.analyzer.used_modules):
            self.analyzer.used_constants.add("COL")
        
        if self.analyzer.used_constants:
            parts.append(self._generate_constants())
        
        module_tables = [f"BRC.{m.split('.')[1]} = BRC.{m.split('.')[1]} or {{}}" for m in sorted(self.analyzer.used_modules)]
        if module_tables:
            parts.append("-- BRC module tables (Don't overwrite existing globals)\n" + "\n".join(module_tables))
        
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
        content = "\n".join([
          f"-- Minimal BRC namespace (Don't overwrite existing globals)\nBRC = BRC or {{}}",
          f"BRC.Config = BRC.Config or {{}}",
          f"BRC.Config.emojis = {get_default_config_boolean('emojis')}",
        ])
        if self.feature_var == "f_pickup_alert":
          content += "\nBRC.Config.unskilled_egos_usable = " + get_default_config_boolean('unskilled_egos_usable')
          bb = match_constant_definition(_get_cached_text(BRC_MODULES["BRC.Configs"]), "Configs.Default.BrandBonus")
          content += "\n" + bb.replace("BRC.Configs.Default.BrandBonus", "BRC.Config.BrandBonus")

        if self._needs_debug() or self._needs_stderr():
          content += "\nBRC.Config.mpr = BRC.Config.mpr or {}"
        if self._needs_debug():
          content += f"\nBRC.Config.mpr.show_debug_messages = {get_default_config_boolean('show_debug_messages')}"
        if self._needs_stderr():
          content += f"\nBRC.Config.mpr.logs_to_stderr = {get_default_config_boolean('logs_to_stderr')}"

        return content
    
    def _generate_constants(self) -> str:
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
        result = [f"-- {module} module"]
        
        if module == "BRC.Data":
            result.append(self._generate_minimal_persist())
        else:
            if module in self.analyzer.init_code_blocks:
                for block in self.analyzer.init_code_blocks[module]:
                    result.append(block)
                result.append('')
            
            if module in self.analyzer.local_functions:
                for func_name in self.analyzer.local_functions[module].keys():
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
        return "-- Minimal persistence system for standalone features\n" + get_minimal_persist_code()
    
    def _generate_config_section(self) -> str:
        config_content = self._extract_config_section()
        if not config_content:
            return ""
        
        config_content = f"{self.feature_var} = {{}}\n" + config_content
        
        # Simplify configs: always enabled, no BRC.txt.color(), no BRC.util.cntl()
        config_content = re.sub(r'(\s+disabled\s*=\s*)true', r'\1false', config_content)
        config_content = re.sub(r'BRC\.txt\.(\w+)\("([^"]+)"\)', r'"<\1>\2</\1>"', config_content)
        config_content = re.sub(r'BRC\.util\.cntl\("([^"]+)"\)', 
                               lambda m: f'string.byte("{m.group(1).upper()}") - 64', config_content)
 
        # Prepend constants that are used in the config
        for c in ["COL"]:
            if f"BRC.{c}." in config_content:
                const = match_constant_definition(_get_cached_text(BRC_CONSTANTS), c)
                config_content = f"\n{const}\n\n{config_content}"


        return config_content
    
    def _generate_feature_code(self) -> str:
        content = re.sub(r'^\s*\w+\.BRC_FEATURE_NAME\s*=.*$', '', self.analyzer.content, flags=re.MULTILINE)
        lines = content.split('\n')
        bounds = self._find_config_section_bounds(lines)
        if bounds is not None:
            start_idx, end_idx = bounds
            content = '\n'.join(lines[:start_idx] + lines[end_idx:])
            content = re.sub(rf'{self.feature_var} = {{}}\n', '', content)

        return content
    
    def _generate_hooks(self) -> str:
        hooks = [h for h in sorted(self.analyzer.used_hooks) if h != "init"]
        needs_queue = self._needs_consume_queue()
        needs_mutes = self._needs_single_turn_mutes()
        if "ready" not in hooks and (needs_queue or needs_mutes):
            hooks = sorted(hooks + ["ready"])
        
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
                    *([f"  BRC.mpr.consume_queue()"] if needs_queue else []),
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
        return f"-- Initialize feature\nif {self.feature_var}.init then {self.feature_var}.init() end"

def process_feature(analyzer: DependencyAnalyzer, output_name: str, display_name: str = None, f_var_name: Optional[str] = None):
    """Process a feature analyzer and generate the standalone output file."""
    if display_name is None:
        display_name = output_name
    
    print(f"Analyzing feature: {display_name}")
    
    analyzer.analyze()
    
    print(f"  Dependencies found:")
    print(f"    Modules: {sorted(analyzer.used_modules)}")
    print(f"    Hooks: {sorted(analyzer.used_hooks)}")
    print(f"    Constants: {sorted(analyzer.used_constants)}")
    
    generator = StandaloneGenerator(analyzer, f_var_name)
    standalone_content = generator.generate()
    standalone_content += "\n}\n"

    output_file = output_dir / f"{output_name}.rc"
    output_file.write_text(standalone_content, encoding='utf-8')
    
    print(f"\nGenerated: {output_file}")
    print(f"  Size: {len(standalone_content)} characters, {len(standalone_content.splitlines())} lines")
    print()

# ============================================================================
# Main Entry Point
# ============================================================================

def main():
    for feature_path in features_dir.glob("*.lua"):
        if "_template" in feature_path.name:
            continue
        analyzer = DependencyAnalyzer(feature_path)
        process_feature(analyzer, feature_path.stem.replace('_', '-'))
    
    # Special handling for pickup-alert: concatenate multiple files
    pickup_alert_dir = features_dir / "pickup-alert"
    pickup_alert_files = [
        "pa-config.lua",
        "pa-main.lua",
        "pa-data.lua",
        "pa-armour.lua",
        "pa-misc.lua",
        "pa-weapons.lua",
    ]
    
    concatenated_content = []
    for filename in pickup_alert_files:
        file_path = pickup_alert_dir / filename
        if file_path.exists():
            concatenated_content.append(file_path.read_text(encoding='utf-8'))
        else:
            print(f"  Warning: {file_path} not found, skipping")
    
    if concatenated_content:
        concatenated_text = '\n'.join(concatenated_content)
        dummy_path = features_dir / "pickup-alert" / "pa-main.lua"
        analyzer = DependencyAnalyzer(dummy_path, content=concatenated_text)
        process_feature(analyzer, "pickup-alert", "pickup-alert (concatenated)", "f_pickup_alert")

if __name__ == "__main__":
    main()
