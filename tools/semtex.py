#!/usr/bin/env python3
"""semtex — semantic TeX preprocessor.

Extracts a concept graph from TeX specs annotated with semantic macros.
Produces a machine-readable registry (JSON) for dependency tracking,
cross-language lookup, and documentation generation.

Usage:
    semtex.py extract FILE [FILE ...]   Extract per-file .semtex.json
    semtex.py merge DIR                 Merge .semtex.json -> registry.json
    semtex.py validate REGISTRY         Validate registry (deps, cycles, files)
    semtex.py mathjax PREAMBLE          Generate MathJax macro config from preamble
"""

import json
import os
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path


# ---------------------------------------------------------------------------
# Macro patterns
# ---------------------------------------------------------------------------

# \concept{id}{Display Name}
RE_CONCEPT = re.compile(r'\\concept\{([^}]+)\}\{([^}]+)\}')
# \depends{concept-id}
RE_DEPENDS = re.compile(r'\\depends\{([^}]+)\}')
# \implements{lang}{module}
RE_IMPLEMENTS = re.compile(r'\\implements\{([^}]+)\}\{([^}]+)\}')
# \axiom{concept-id}{axiom-name}
RE_AXIOM = re.compile(r'\\axiom\{([^}]+)\}\{([^}]+)\}')
# \uses{concept-id}
RE_USES = re.compile(r'\\uses\{([^}]+)\}')
# \stacksref{tag}
RE_STACKSREF = re.compile(r'\\stacksref\{([^}]+)\}')
# \nlabref{page}
RE_NLABREF = re.compile(r'\\nlabref\{([^}]+)\}')
# \newterm{term}
RE_NEWTERM = re.compile(r'\\newterm\{([^}]+)\}')
# \newmath{symbol}
RE_NEWMATH = re.compile(r'\\newmath\{([^}]+)\}')
# \label{...}
RE_LABEL = re.compile(r'\\label\{([^}]+)\}')
# \section{...}
RE_SECTION = re.compile(r'\\section\{([^}]+)\}')


# ---------------------------------------------------------------------------
# Extract
# ---------------------------------------------------------------------------

def extract_file(filepath):
    """Extract semantic metadata from a single .tex file."""
    filepath = Path(filepath)
    concepts = []
    current_concept = None

    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()

            # New concept declaration resets context
            m = RE_CONCEPT.search(line)
            if m:
                if current_concept:
                    concepts.append(current_concept)
                current_concept = {
                    'concept_id': m.group(1),
                    'name': m.group(2),
                    'file': str(filepath),
                    'depends': [],
                    'uses': [],
                    'axioms': [],
                    'implements': {},
                    'stacks_refs': [],
                    'nlab_refs': [],
                    'terms_introduced': [],
                    'symbols_introduced': [],
                    'labels': [],
                }
                continue

            if current_concept is None:
                continue

            # Dependencies
            for m in RE_DEPENDS.finditer(line):
                dep = m.group(1).strip()
                if dep and dep not in current_concept['depends']:
                    current_concept['depends'].append(dep)

            # Uses (weak refs)
            for m in RE_USES.finditer(line):
                ref = m.group(1).strip()
                if ref and ref not in current_concept['uses']:
                    current_concept['uses'].append(ref)

            # Implementations
            for m in RE_IMPLEMENTS.finditer(line):
                lang = m.group(1).strip()
                mod = m.group(2).strip()
                current_concept['implements'].setdefault(lang, [])
                if mod not in current_concept['implements'][lang]:
                    current_concept['implements'][lang].append(mod)

            # Axioms
            for m in RE_AXIOM.finditer(line):
                axiom_name = m.group(2).strip()
                if axiom_name not in current_concept['axioms']:
                    current_concept['axioms'].append(axiom_name)

            # Stacks Project refs
            for m in RE_STACKSREF.finditer(line):
                tag = m.group(1).strip()
                if tag not in current_concept['stacks_refs']:
                    current_concept['stacks_refs'].append(tag)

            # nLab refs
            for m in RE_NLABREF.finditer(line):
                page = m.group(1).strip()
                if page not in current_concept['nlab_refs']:
                    current_concept['nlab_refs'].append(page)

            # Terms introduced
            for m in RE_NEWTERM.finditer(line):
                term = m.group(1).strip()
                if term not in current_concept['terms_introduced']:
                    current_concept['terms_introduced'].append(term)

            # Symbols introduced
            for m in RE_NEWMATH.finditer(line):
                sym = m.group(1).strip()
                if sym not in current_concept['symbols_introduced']:
                    current_concept['symbols_introduced'].append(sym)

            # Labels
            for m in RE_LABEL.finditer(line):
                label = m.group(1).strip()
                # Skip labels generated by \concept and \axiom
                if not label.startswith('concept:') and not label.startswith('axiom:'):
                    if label not in current_concept['labels']:
                        current_concept['labels'].append(label)

    if current_concept:
        concepts.append(current_concept)

    return concepts


def cmd_extract(files):
    """Extract semantic data from .tex files, write .semtex.json alongside."""
    for filepath in files:
        filepath = Path(filepath)
        if not filepath.exists():
            print(f"warning: {filepath} not found, skipping", file=sys.stderr)
            continue

        concepts = extract_file(filepath)
        out_path = filepath.with_suffix('.semtex.json')
        with open(out_path, 'w', encoding='utf-8') as f:
            json.dump({'file': str(filepath), 'concepts': concepts}, f, indent=2)
        print(f"  extracted: {out_path} ({len(concepts)} concepts)")


# ---------------------------------------------------------------------------
# Merge
# ---------------------------------------------------------------------------

def cmd_merge(spec_dir):
    """Merge all .semtex.json files into a single registry.json."""
    spec_dir = Path(spec_dir)
    semtex_files = sorted(spec_dir.rglob('*.semtex.json'))

    if not semtex_files:
        print("error: no .semtex.json files found", file=sys.stderr)
        sys.exit(1)

    concepts = {}
    dependency_dag = {}
    stacks_index = {}
    nlab_index = {}

    for sf in semtex_files:
        with open(sf, 'r', encoding='utf-8') as f:
            data = json.load(f)
        for c in data.get('concepts', []):
            cid = c['concept_id']
            if cid in concepts:
                print(f"warning: duplicate concept '{cid}' in {sf}", file=sys.stderr)
            concepts[cid] = c
            dependency_dag[cid] = c.get('depends', [])
            for tag in c.get('stacks_refs', []):
                stacks_index[tag] = cid
            for page in c.get('nlab_refs', []):
                nlab_index[page] = cid

    # Compute back-references
    for cid, c in concepts.items():
        c['back_refs'] = []
    for cid, deps in dependency_dag.items():
        for dep in deps:
            if dep in concepts:
                if cid not in concepts[dep]['back_refs']:
                    concepts[dep]['back_refs'].append(cid)

    # Validate: all depends targets exist
    errors = []
    for cid, deps in dependency_dag.items():
        for dep in deps:
            if dep not in concepts:
                errors.append(f"concept '{cid}' depends on unknown '{dep}'")

    # Validate: DAG is acyclic (topological sort)
    visited = set()
    in_stack = set()
    topo_order = []

    def visit(node):
        if node in in_stack:
            errors.append(f"cycle detected involving '{node}'")
            return
        if node in visited:
            return
        in_stack.add(node)
        for dep in dependency_dag.get(node, []):
            if dep in concepts:
                visit(dep)
        in_stack.discard(node)
        visited.add(node)
        topo_order.append(node)

    for cid in concepts:
        visit(cid)

    if errors:
        for e in errors:
            print(f"error: {e}", file=sys.stderr)
        sys.exit(1)

    # Build symbol table from implements
    symbol_table = {}
    for cid, c in concepts.items():
        symbol_table[c['name']] = {
            'concept': cid,
            **{lang: mods for lang, mods in c.get('implements', {}).items()}
        }

    registry = {
        'version': 1,
        'generated': datetime.now(timezone.utc).isoformat(),
        'concepts': concepts,
        'dependency_dag': dependency_dag,
        'topological_order': topo_order,
        'stacks_index': stacks_index,
        'nlab_index': nlab_index,
        'symbol_table': symbol_table,
    }

    out_path = spec_dir / 'registry.json'
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(registry, f, indent=2)
    print(f"  registry: {out_path} ({len(concepts)} concepts, {len(topo_order)} in topo order)")


# ---------------------------------------------------------------------------
# Validate
# ---------------------------------------------------------------------------

def cmd_validate(registry_path, project_root='.'):
    """Validate registry: deps resolve, no cycles, implementation files exist."""
    project_root = Path(project_root)

    with open(registry_path, 'r', encoding='utf-8') as f:
        registry = json.load(f)

    errors = []
    warnings = []

    # File existence for implements
    lang_roots = {
        'haskell': project_root / 'src' / 'haskell' / 'src',
        'agda': project_root / 'src' / 'agda',
        'lisp': project_root / 'src' / 'lisp' / 'src',
    }

    for cid, c in registry['concepts'].items():
        for lang, modules in c.get('implements', {}).items():
            root = lang_roots.get(lang)
            if root is None:
                warnings.append(f"concept '{cid}': unknown language '{lang}'")
                continue
            for mod in modules:
                if lang == 'haskell':
                    fpath = root / (mod.replace('.', '/') + '.hs')
                elif lang == 'agda':
                    fpath = root / (mod.replace('.', '/') + '.agda')
                elif lang == 'lisp':
                    fpath = root / (mod + '.lisp')
                else:
                    continue

                if not fpath.exists():
                    errors.append(
                        f"concept '{cid}': {lang} module '{mod}' -> "
                        f"file not found: {fpath}"
                    )

    # Stacks tag uniqueness
    tag_counts = defaultdict(list)
    for cid, c in registry['concepts'].items():
        for tag in c.get('stacks_refs', []):
            tag_counts[tag].append(cid)
    for tag, cids in tag_counts.items():
        if len(cids) > 1:
            warnings.append(f"Stacks tag '{tag}' used by multiple concepts: {cids}")

    for w in warnings:
        print(f"warning: {w}", file=sys.stderr)
    for e in errors:
        print(f"error: {e}", file=sys.stderr)

    if errors:
        print(f"\nvalidation FAILED ({len(errors)} errors, {len(warnings)} warnings)")
        sys.exit(1)
    else:
        print(f"  validation OK ({len(registry['concepts'])} concepts, {len(warnings)} warnings)")


# ---------------------------------------------------------------------------
# MathJax macro generation
# ---------------------------------------------------------------------------

RE_DECLAREMATHOP = re.compile(
    r'\\DeclareMathOperator\{\\([^}]+)\}\{([^}]+)\}'
)

# Semantic/non-math macros to skip in MathJax output
SKIP_MACROS = {
    'concept', 'depends', 'implements', 'axiom', 'uses',
    'stacksref', 'nlabref', 'newterm', 'newmath',
}


def _extract_braced(text, pos):
    """Extract a brace-balanced group starting at text[pos] == '{'.
    Returns (content, end_pos) where end_pos is after the closing '}'."""
    if pos >= len(text) or text[pos] != '{':
        return None, pos
    depth = 0
    start = pos + 1
    i = pos
    while i < len(text):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                return text[start:i], i + 1
        i += 1
    return None, pos


def _parse_newcommands(content):
    """Parse \\newcommand definitions with proper brace matching."""
    results = []
    i = 0
    while i < len(content):
        idx = content.find('\\newcommand', i)
        if idx == -1:
            break
        # Also handle \newcommand*
        pos = idx + len('\\newcommand')
        if pos < len(content) and content[pos] == '*':
            pos += 1
        # Extract name: \newcommand{\name}
        name_body, pos = _extract_braced(content, pos)
        if name_body is None or not name_body.startswith('\\'):
            i = idx + 1
            continue
        name = name_body[1:]  # strip leading backslash
        # Optional [nargs]
        nargs = None
        while pos < len(content) and content[pos] in ' \t\n':
            pos += 1
        if pos < len(content) and content[pos] == '[':
            end_bracket = content.find(']', pos)
            if end_bracket != -1:
                nargs = content[pos+1:end_bracket].strip()
                pos = end_bracket + 1
        # Extract body
        while pos < len(content) and content[pos] in ' \t\n':
            pos += 1
        body, pos = _extract_braced(content, pos)
        if body is not None:
            results.append((name, nargs, body))
        i = pos if pos > idx else idx + 1
    return results


def cmd_mathjax(preamble_path):
    """Generate MathJax macro config from preamble.tex."""
    with open(preamble_path, 'r', encoding='utf-8') as f:
        content = f.read()

    macros = {}

    for name, nargs, body in _parse_newcommands(content):
        if name in SKIP_MACROS:
            continue

        # Strip TeX comments (% to end of line) and collapse whitespace
        body_clean = re.sub(r'%[^\n]*', '', body)
        body_clean = re.sub(r'\s+', ' ', body_clean).strip()
        # Escape for JS string
        body_js = body_clean.replace('\\', '\\\\')

        if nargs:
            macros[name] = [body_js, int(nargs)]
        else:
            macros[name] = body_js

    for m in RE_DECLAREMATHOP.finditer(content):
        name = m.group(1)
        text = m.group(2)
        macros[name] = f'\\\\operatorname{{{text}}}'

    # Output as JS config
    print("    MathJax = {")
    print("      tex: {")
    print("        inlineMath: [['\\\\(', '\\\\)']],")
    print("        displayMath: [['\\\\[', '\\\\]']],")
    print("        macros: {")
    items = sorted(macros.items())
    for i, (name, val) in enumerate(items):
        comma = ',' if i < len(items) - 1 else ''
        if isinstance(val, list):
            print(f"          {name}: ['{val[0]}', {val[1]}]{comma}")
        else:
            print(f"          {name}: '{val}'{comma}")
    print("        }")
    print("      }")
    print("    };")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def usage():
    print(__doc__.strip())
    sys.exit(1)


def main():
    if len(sys.argv) < 2:
        usage()

    cmd = sys.argv[1]

    if cmd == 'extract':
        if len(sys.argv) < 3:
            print("error: extract requires at least one .tex file", file=sys.stderr)
            sys.exit(1)
        cmd_extract(sys.argv[2:])

    elif cmd == 'merge':
        if len(sys.argv) != 3:
            print("error: merge requires a directory", file=sys.stderr)
            sys.exit(1)
        cmd_merge(sys.argv[2])

    elif cmd == 'validate':
        if len(sys.argv) < 3:
            print("error: validate requires a registry.json path", file=sys.stderr)
            sys.exit(1)
        project_root = sys.argv[3] if len(sys.argv) > 3 else '.'
        cmd_validate(sys.argv[2], project_root)

    elif cmd == 'mathjax':
        if len(sys.argv) != 3:
            print("error: mathjax requires a preamble.tex path", file=sys.stderr)
            sys.exit(1)
        cmd_mathjax(sys.argv[2])

    else:
        print(f"error: unknown command '{cmd}'", file=sys.stderr)
        usage()


if __name__ == '__main__':
    main()
