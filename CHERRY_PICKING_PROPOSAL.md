# Cherry-Picking Features - Proposed Solutions

## Problem
Users want to copy-paste individual features into their RC files, but features have many dependencies on BRC core and util modules. Currently, users must copy the entire BRC core (~900+ lines) even if they only want one simple feature.

## Proposed Solutions

### Option 1: Standalone Feature Generator (Recommended)
**Create a script that generates standalone feature files with minimal dependencies**

A Python script that:
1. Analyzes a feature file to detect which BRC modules it uses (BRC.mpr, BRC.txt, BRC.Data, etc.)
2. Extracts only the necessary functions from those modules
3. Creates a minimal hook system (simpler than full BRC core)
4. Generates a single standalone file that can be copy-pasted

**Pros:**
- Users get a single file to copy-paste
- Only includes code actually needed
- Works independently (no BRC core required)
- Can be automated for all features

**Cons:**
- Requires building/maintaining the dependency analyzer
- Generated files may be harder to debug
- Need to handle edge cases (e.g., features that use config system)

**Example usage:**
```bash
python build/standalone_feature.py announce-items.lua
# Generates: bin/standalone_announce-items.rc
```

### Option 2: Minimal Standalone Core
**Create a stripped-down core with only essentials**

A minimal version of the core that:
- Includes only BRC.mpr, BRC.txt, BRC.Data (basic versions)
- Simple hook registration (no full config system)
- Much smaller than full core (~200-300 lines vs 900+)

**Pros:**
- Simpler than full core
- Still modular (users can see what they're including)
- Easier to maintain than full dependency analysis

**Cons:**
- Still requires copying core + feature
- May not support all features (especially those using config system)
- Need to document which features work with minimal core

### Option 3: Dependency Documentation + Helper Script
**Document dependencies and provide a helper script**

1. Document what each feature needs (e.g., "announce-items needs: BRC.txt, BRC.mpr")
2. Create a script that copies feature + required modules

**Pros:**
- Simple to implement
- Transparent (users see what's included)
- Easy to maintain

**Cons:**
- Still requires copying multiple files
- Manual dependency tracking
- Not as convenient as single-file solution

### Option 4: Pre-built Standalone Bundles
**Generate standalone versions of popular features in `bin/`**

Similar to Option 1, but pre-generate standalone versions of commonly requested features.

**Pros:**
- Ready to use (no build step for users)
- Can be version-controlled
- Users can see examples

**Cons:**
- Only covers pre-built features
- Need to regenerate when features change
- Maintenance overhead

## Recommendation

**Combine Option 1 + Option 4:**
1. Build the standalone feature generator script
2. Pre-generate standalone versions of popular/simple features
3. Document the process in README

This gives users:
- Ready-to-use standalone files for common features
- Ability to generate standalone versions of any feature
- Single-file copy-paste experience

## Implementation Notes

### What a standalone feature needs:
1. **Minimal BRC namespace** - Just `BRC = {}` and the modules used
2. **Hook functions** - Simple versions of `ready()`, `autopickup()`, etc. that call the feature
3. **Required util modules** - Only the functions actually used
4. **Feature code** - The feature itself

### Challenges:
- Features using `BRC.Data.persist()` need a minimal persistence system
- Features using `BRC.Config` need a minimal config system
- Features using complex util functions need those extracted
- Hook registration needs to work without full BRC core

### Example: Minimal standalone structure
```lua
-- Minimal BRC setup
BRC = {}
BRC.mpr = { ... } -- Only functions used by feature
BRC.txt = { ... } -- Only functions used by feature
BRC.Data = { ... } -- Minimal persistence

-- Simple hook registration
function ready()
  if feature.ready then feature.ready() end
end

-- Feature code
feature = { ... }
```

## Next Steps

1. **Analyze feature dependencies** - Scan all features to understand common patterns
2. **Build dependency analyzer** - Script to detect what a feature uses
3. **Create minimal core generator** - Extract only needed functions
4. **Generate standalone files** - For a few test features first
5. **Update README** - Add cherry-picking guide
6. **Pre-generate popular features** - Add to `bin/` directory

