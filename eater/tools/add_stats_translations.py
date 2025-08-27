import json
import os
from glob import glob

ROOT = os.path.dirname(os.path.dirname(__file__))
LOCALE_DIR = os.path.join(ROOT, 'Localization')

# New keys to ensure exist across all locales (English defaults)
NEW_KEYS = {
    # Chart tabs
    "stats.chart.insights": "Insights",
    "stats.chart.calories": "Calories",
    "stats.chart.macros": "Macronutrients",
    "stats.chart.personweight": "Body Weight",
    "stats.chart.foodweight": "Food Weight",
    "stats.chart.trends": "Trends",

    # Axes and labels
    "stats.axis.date": "Date",
    "stats.axis.calories": "Calories",
    "stats.axis.weight": "Weight",
    "stats.axis.foodweight": "Food Weight",
    "stats.axis.proteins": "Proteins",
    "stats.axis.fats": "Fats",
    "stats.axis.carbs": "Carbs",
    "stats.axis.fiber": "Fiber",

    # Weight single-point text
    "stats.weight.current": "Current",
    "stats.weight.latest": "Latest",
    "stats.weight.empty.title": "No weight data available",
    "stats.weight.empty.subtitle": "Submit weight via camera or manual entry",

    # Trend section
    "stats.trend.title": "Trend Analysis",
    "stats.trend.calories": "Calories Trend",
    "stats.trend.body_weight": "Body Weight Trend",
    "stats.trend.food_weight": "Food Weight Trend",

    # Insights section
    "stats.insights.title": "Insights Overview",
    "stats.insights.active_days": "Active Days",
    "stats.insights.avg_daily_calories": "Avg Daily Calories",
    "stats.insights.avg_food_weight": "Avg Food Weight",
    "stats.insights.avg_protein": "Avg Protein",
    "stats.insights.avg_fiber": "Avg Fiber",
    "stats.insights.avg_body_weight": "Avg Body Weight",

    # Summary section
    "stats.summary.title_format": "Summary (%@)",
    "stats.summary.avg_calories": "Avg Calories",
    "stats.summary.avg_food": "Avg Food",
    "stats.summary.avg_protein": "Avg Protein",
    "stats.summary.avg_fiber": "Avg Fiber",

    # Units
    "units.g": "g",
    "units.per_day_format": "%@/day",
}

def update_locale_file(path: str) -> bool:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        changed = False
        for k, v in NEW_KEYS.items():
            if k not in data:
                data[k] = v
                changed = True
        if changed:
            # Sort keys for cleanliness
            data_sorted = {k: data[k] for k in sorted(data.keys())}
            with open(path, 'w', encoding='utf-8') as f:
                json.dump(data_sorted, f, ensure_ascii=False, indent=2)
        return changed
    except Exception as e:
        print(f"Failed to update {path}: {e}")
        return False


def main():
    files = sorted(glob(os.path.join(LOCALE_DIR, '*.json')))
    total_changed = 0
    for p in files:
        if os.path.basename(p).lower() == 'contents.json':
            continue
        if update_locale_file(p):
            total_changed += 1
            print(f"Updated: {p}")
    print(f"Done. Locales updated: {total_changed}/{len(files)}")

if __name__ == '__main__':
    main()
