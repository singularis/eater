#!/usr/bin/env python3
"""
Script to patch all language files with weight motivation strings.
Uses English as the source since translations should be done later.
"""

import json
import os
from pathlib import Path

# Weight motivation strings to add (English - will be used for all languages initially)
WEIGHT_MOTIVATION_STRINGS = {
    "weight.loss.title": "🎉 You Lost %dg!",
    "weight.compare.50g": "🥚 That's the weight of a large egg! Great start!",
    "weight.compare.100g": "🍎 That's the weight of a medium apple! Keep going!",
    "weight.compare.150g": "🥝 That's the weight of a kiwi fruit! Nice progress!",
    "weight.compare.200g": "🍌 That's the weight of a banana! You're doing great!",
    "weight.compare.250g": "🍐 That's the weight of a pear! Awesome work!",
    "weight.compare.300g": "🥤 That's the weight of a can of soda! Amazing!",
    "weight.compare.350g": "🍊 That's the weight of a large orange! Fantastic!",
    "weight.compare.400g": "🥭 That's the weight of a mango! Incredible!",
    "weight.compare.450g": "🥔 That's the weight of a potato! Superb!",
    "weight.compare.500g": "🧈 That's half a kilogram - like a butter pack! Wow!",
    "weight.compare.550g": "🥥 That's the weight of a coconut! Outstanding!",
    "weight.compare.600g": "🏀 That's the weight of a basketball! Brilliant!",
    "weight.compare.650g": "🍇 That's the weight of a bunch of grapes! Excellent!",
    "weight.compare.700g": "🍈 That's the weight of a small melon! Wonderful!",
    "weight.compare.750g": "🍷 That's a bottle of wine! Cheers to your progress!",
    "weight.compare.800g": "🍚 That's almost a kilogram of rice! Phenomenal!",
    "weight.compare.850g": "📖 That's the weight of a thick book! Keep reading your success story!",
    "weight.compare.900g": "💧 That's almost a liter of water! Refreshing progress!",
    "weight.compare.950g": "🎾 That's about 15 tennis balls! You're a champion!",
    "weight.compare.1kg": "🎂 That's a whole kilogram - like a bag of flour! Celebration time!",
    "weight.compare.1_25kg": "🍉 That's the weight of a small watermelon! Juicy progress!",
    "weight.compare.1_5kg": "💻 That's like carrying a laptop less! Lightening your load!",
    "weight.compare.1_75kg": "👟 That's like 3 pairs of running shoes! Sprint to success!",
    "weight.compare.2kg": "🏋️ That's like losing a small dumbbell! Strength in progress!",
    "weight.compare.2_5kg": "🐱 That's the weight of a cat! Feline good about this!",
    "weight.compare.3kg": "🥔 That's like a bag of potatoes - amazing progress! 🌟",
    "weight.compare.4kg": "👶 That's almost a newborn baby's weight! Incredible journey!",
    "weight.compare.5kg": "🎳 Incredible progress! That's like losing a bowling ball! 🏆",
    "weight.compare.default": "💪 Every gram counts! Keep up the great work! 🌟"
}

def patch_language_file(filepath: Path) -> bool:
    """Patch a single language file with weight motivation strings."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Check if already patched
        if "weight.loss.title" in data:
            print(f"  ✓ {filepath.name} - already patched")
            return False
        
        # Add the weight motivation strings
        data.update(WEIGHT_MOTIVATION_STRINGS)
        
        # Write back with proper formatting
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write('\n')  # Add trailing newline
        
        print(f"  ✓ {filepath.name} - patched successfully")
        return True
    except Exception as e:
        print(f"  ✗ {filepath.name} - error: {e}")
        return False

def main():
    """Main function to patch all language files."""
    script_dir = Path(__file__).parent
    
    # Find all .json files (excluding any potential non-language files)
    json_files = list(script_dir.glob("*.json"))
    
    print(f"Found {len(json_files)} language files to process:")
    print()
    
    patched = 0
    skipped = 0
    errors = 0
    
    for filepath in sorted(json_files):
        result = patch_language_file(filepath)
        if result:
            patched += 1
        elif result is False:
            skipped += 1
        else:
            errors += 1
    
    print()
    print(f"Summary: {patched} patched, {skipped} already done, {errors} errors")

if __name__ == "__main__":
    main()
