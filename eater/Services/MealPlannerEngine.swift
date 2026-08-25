import Foundation

enum MealPlannerEngine {
  static let variantCount = 5

  private static let snackFoods = ["yogurt", "cottage", "yogurt", "kefir", "cottage"]
  private static let overFoods = ["tea", "apple", "tomato", "yogurt", "tea"]
  private static let per100: [String: (p: Double, c: Double, f: Double)] = [
    "chicken": (31, 0, 3.6),
    "fish": (22, 0, 3),
    "mince": (26, 0, 14),
    "beans": (8, 20, 0.5),
    "tuna": (25, 0, 1),
    "cottage": (12, 3, 4),
    "yogurt": (9, 4, 0.4),
    "kefir": (3, 4, 1),
    "cheese": (25, 1, 27),
    "rice": (2.7, 28, 0.3),
    "potatoes": (2, 17, 0.1),
    "buckwheat": (3.4, 20, 0.6),
    "pasta": (5, 25, 1),
    "oats": (13, 60, 7),
    "bread": (9, 49, 3),
    "vegetables": (2, 5, 0.2),
    "berries": (1, 12, 0.3),
    "banana": (1.1, 23, 0.3),
    "apple": (0.3, 14, 0.2),
    "tomato": (0.9, 4, 0.2),
    "olive_oil": (0, 0, 100),
    "nuts": (20, 20, 50),
    "chicken_soup": (5, 5, 2),
    "vegetable_soup": (2, 6, 1.5),
    "tuna_salad": (11, 5, 7),
    "chicken_salad": (13, 4, 6),
    "baked_chicken": (31, 0, 3.6),
    "baked_fish": (22, 0, 3),
    "baked_potatoes": (2, 17, 0.1),
  ]

  private static let emptyMenus: [[(String, [(String, Int, Int)])]] = [
    [
      ("breakfast", [("oats", 50, 60), ("yogurt", 150, 180), ("banana", 80, 100)]),
      ("lunch", [("chicken_soup", 400, 500), ("bread", 40, 60)]),
      ("dinner", [("baked_fish", 150, 170), ("baked_potatoes", 250, 300), ("vegetables", 150, 200)]),
    ],
    [
      ("breakfast", [("yogurt", 180, 200), ("berries", 80, 100), ("bread", 40, 60)]),
      ("lunch", [("tuna_salad", 280, 350), ("bread", 40, 60)]),
      ("dinner", [("chicken", 140, 160), ("pasta", 160, 200), ("vegetables", 150, 200)]),
    ],
    [
      ("breakfast", [("cottage", 160, 180), ("apple", 150, 180), ("bread", 40, 60)]),
      ("lunch", [("vegetable_soup", 400, 500), ("bread", 40, 60), ("chicken", 100, 120)]),
      ("dinner", [("baked_chicken", 140, 160), ("baked_potatoes", 250, 300), ("vegetables", 150, 200)]),
    ],
    [
      ("breakfast", [("oats", 50, 60), ("berries", 80, 100), ("yogurt", 120, 150)]),
      ("lunch", [("chicken_salad", 250, 320), ("bread", 40, 60)]),
      ("dinner", [("pasta", 180, 220), ("tuna", 100, 120), ("vegetables", 150, 200)]),
    ],
    [
      ("breakfast", [("yogurt", 180, 200), ("banana", 80, 100), ("oats", 30, 40)]),
      ("lunch", [("mince", 120, 140), ("pasta", 180, 220), ("vegetables", 200, 250)]),
      ("dinner", [("baked_fish", 150, 170), ("rice", 180, 220), ("vegetables", 150, 200)]),
    ],
  ]

  static func plan(
    language: String,
    variant: Int,
    mealsToday: Int,
    remaining: MealPlannerRemaining
  ) -> MealPlanResult {
    let v = ((variant % variantCount) + variantCount) % variantCount
    let mode: String
    if mealsToday <= 0 {
      mode = "empty_day"
    } else if remaining.kcal < 80 {
      mode = "over_calories"
    } else {
      mode = "remaining"
    }

    let protein = max(0, remaining.protein)
    let carbs = max(0, remaining.carbs)
    let fats = max(0, remaining.fats)
    let sugar = max(0, remaining.sugar)
    let remainingMap: [String: Int] = [
      "protein_g": Int(protein.rounded()),
      "carbs_g": Int(carbs.rounded()),
      "fats_g": Int(fats.rounded()),
      "sugar_g": Int(sugar.rounded()),
    ]

    var sections: [(id: String, emoji: String, items: [[String: Any]])] = []
    var notes: [[String: Any]] = []

    if mode == "empty_day" {
      let emoji = ["breakfast": "🥣", "lunch": "🍽️", "dinner": "🌙"]
      for (sectionId, foods) in emptyMenus[v] {
        let items: [[String: Any]] = foods.map { ["food": $0.0, "lo": $0.1, "hi": $0.2] }
        sections.append((sectionId, emoji[sectionId] ?? "🍴", items))
      }
      notes.append(["id": "easy_cook"])
    } else if mode == "over_calories" {
      var items: [[String: Any]] = [["food": overFoods[v], "lo": 0, "hi": 0]]
      if v == 4 {
        items.append(["food": overFoods[(v + 2) % overFoods.count], "lo": 0, "hi": 0])
      }
      sections.append(("light", "🍵", items))
      notes.append(["id": "over_calories"])
    } else {
      let snack = snackFoods[v]
      let styled = mainStyle(v, protein: protein, carbs: carbs, fats: fats)
      var snackItems: [[String: Any]] = []
      let sR = rangeG(gramsFor(snack, protein * 0.22, "p"), spread: 10, min: 120, max: nil)
      snackItems.append(["food": snack, "lo": sR.0, "hi": sR.1])
      if sugar >= 12 {
        snackItems.append(["food": "berries", "lo": 80, "hi": 100])
      }
      if carbs * 0.20 >= 20 && carbs >= 50 {
        snackItems.append(["food": "banana", "lo": 60, "hi": 100, "optional_carbs": true])
      }
      sections.append(("main_meal", styled.emoji, styled.items))
      sections.append(("later_snack", "🥛", snackItems))
    }

    let text = render(
      language: language,
      mode: mode,
      remaining: remainingMap,
      sections: sections,
      notes: notes
    )
    return MealPlanResult(text: text, variant: v, variantCount: variantCount)
  }

  static func extraTips(language: String) -> String {
    let nuts = t(language, "nuts_note", ["lo": 10, "hi": 15])
    let fruit = t(
      language,
      "fruit_veg",
      [
        "fruit_lo": 150,
        "fruit_hi": 200,
        "veg_lo": 400,
        "veg_hi": 500,
      ]
    )
    return "\(nuts)\n\n\(fruit)"
  }

  static func extrasTitle(language: String) -> String {
    let s = t(language, "extras")
    if s.isEmpty || s == "extras" {
      return loc("meal_planner.extras", "Extra tips")
    }
    return s
  }

  private static func carbRange(_ food: String, _ carbs: Double, spread: Int = 25) -> (Int, Int) {
    var maximum = ["rice", "pasta", "buckwheat"].contains(food) ? 300 : 400
    if food == "bread" { maximum = 80 }
    if food == "baked_potatoes" { maximum = 400 }
    let minimum = food == "bread" ? 40 : 80
    return rangeG(gramsFor(food, carbs, "c"), spread: spread, min: minimum, max: maximum)
  }

  private static func vegRange(_ carbs: Double) -> (Int, Int) {
    carbs >= 40 ? (200, 250) : (150, 200)
  }

  private static func mainStyle(
    _ variant: Int,
    protein: Double,
    carbs: Double,
    fats: Double
  ) -> (emoji: String, items: [[String: Any]]) {
    switch variant {
    case 1:
      let soup = rangeG(gramsFor("chicken_soup", protein * 0.70, "p"), spread: 40, min: 350, max: 550)
      let bread = carbRange("bread", max(carbs * 0.35, 25), spread: 10)
      return (
        "🍲",
        [
          [
            "food": "chicken_soup", "lo": soup.0, "hi": soup.1,
            "or_food": "vegetable_soup", "or_lo": soup.0, "or_hi": soup.1,
          ],
          ["food": "bread", "lo": bread.0, "hi": bread.1],
        ]
      )
    case 2:
      let salad = rangeG(gramsFor("tuna_salad", protein * 0.80, "p"), spread: 25, min: 250, max: 420)
      let alt = rangeG(gramsFor("chicken_salad", protein * 0.80, "p"), spread: 25, min: 250, max: 420)
      var items: [[String: Any]] = [
        [
          "food": "tuna_salad", "lo": salad.0, "hi": salad.1,
          "or_food": "chicken_salad", "or_lo": alt.0, "or_hi": alt.1,
        ],
        ["food": "vegetables", "lo": 150, "hi": 200],
      ]
      if carbs >= 40 {
        let bread = carbRange("bread", carbs * 0.30, spread: 10)
        items.append(["food": "bread", "lo": bread.0, "hi": bread.1])
      }
      if fats >= 6 {
        items.append(["food": "olive_oil", "lo": 5, "hi": 8, "suffix": "max"])
      }
      return ("🥗", items)
    case 3:
      let fish = rangeG(gramsFor("baked_fish", protein * 0.80, "p"), spread: 10, min: 80, max: 220)
      let chicken = rangeG(gramsFor("baked_chicken", protein * 0.80, "p"), spread: 10, min: 80, max: 220)
      let pot = carbRange("baked_potatoes", carbs * 0.55)
      let veg = vegRange(carbs)
      return (
        "🥘",
        [
          [
            "food": "baked_fish", "lo": fish.0, "hi": fish.1,
            "or_food": "baked_chicken", "or_lo": chicken.0, "or_hi": chicken.1,
          ],
          ["food": "baked_potatoes", "lo": pot.0, "hi": pot.1],
          ["food": "vegetables", "lo": veg.0, "hi": veg.1],
        ]
      )
    case 4:
      let mince = rangeG(gramsFor("mince", protein * 0.80, "p"), spread: 10, min: 80, max: 220)
      let pasta = carbRange("pasta", carbs * 0.55)
      let rice = carbRange("rice", carbs * 0.55)
      let veg = vegRange(carbs)
      var items: [[String: Any]] = [
        ["food": "mince", "lo": mince.0, "hi": mince.1],
        [
          "food": "pasta", "lo": pasta.0, "hi": pasta.1,
          "or_food": "rice", "or_lo": rice.0, "or_hi": rice.1,
        ],
        ["food": "vegetables", "lo": veg.0, "hi": veg.1],
      ]
      if fats >= 8 {
        items.append(["food": "olive_oil", "lo": 5, "hi": 8, "suffix": "max"])
      }
      return ("🍝", items)
    default:
      let chicken = rangeG(gramsFor("chicken", protein * 0.80, "p"), spread: 10, min: 80, max: 220)
      let rice = carbRange("rice", carbs * 0.55)
      let pot = carbRange("potatoes", carbs * 0.55)
      let veg = vegRange(carbs)
      var items: [[String: Any]] = [
        ["food": "chicken", "lo": chicken.0, "hi": chicken.1],
        [
          "food": "rice", "lo": rice.0, "hi": rice.1,
          "or_food": "potatoes", "or_lo": pot.0, "or_hi": pot.1,
        ],
        ["food": "vegetables", "lo": veg.0, "hi": veg.1],
      ]
      if fats >= 8 {
        items.append(["food": "olive_oil", "lo": 5, "hi": fats >= 14 ? 10 : 8, "suffix": "max"])
      }
      return ("🍗", items)
    }
  }

  private static func gramsFor(_ food: String, _ nutrient: Double, _ key: String) -> Double {
    guard let per = per100[food] else { return 0 }
    let perG: Double
    switch key {
    case "p": perG = per.p
    case "c": perG = per.c
    default: perG = per.f
    }
    guard perG > 0 else { return 0 }
    return nutrient / perG * 100
  }

  private static func rangeG(_ grams: Double, spread: Int, min minimum: Int, max maximum: Int?) -> (Int, Int) {
    var g = max(minimum, Int((grams / 5.0).rounded() * 5))
    if let maximum {
      g = Swift.min(g, maximum)
      if g < minimum { g = minimum }
    }
    var lo = max(minimum, g - spread)
    var hi = g + spread
    if let maximum {
      hi = Swift.min(hi, maximum)
      lo = Swift.min(lo, hi)
    }
    if hi <= lo {
      hi = lo + max(5, spread)
      if let maximum { hi = Swift.min(hi, maximum) }
    }
    return (lo, hi)
  }

  private static func render(
    language: String,
    mode: String,
    remaining: [String: Int],
    sections: [(id: String, emoji: String, items: [[String: Any]])],
    notes: [[String: Any]]
  ) -> String {
    var lines: [String] = []
    if mode == "empty_day" {
      lines.append(t(language, "empty_intro"))
      lines.append("")
    } else if mode == "over_calories" {
      lines.append(t(language, "over_intro"))
      lines.append("")
    } else {
      lines.append(t(language, "remaining_header"))
      lines.append("")
      lines.append(t(language, "protein", ["n": remaining["protein_g"] ?? 0]))
      lines.append(t(language, "carbs", ["n": remaining["carbs_g"] ?? 0]))
      lines.append(t(language, "fats", ["n": remaining["fats_g"] ?? 0]))
      lines.append(t(language, "sugar", ["n": remaining["sugar_g"] ?? 0]))
      lines.append("")
      lines.append(t(language, "good_option"))
      lines.append("")
    }
    for section in sections {
      lines.append("\(section.emoji) \(t(language, section.id))".trimmingCharacters(in: .whitespaces))
      lines.append("")
      for item in section.items {
        lines.append(foodLine(language, item))
      }
      lines.append("")
    }
    for note in notes {
      let nid = note["id"] as? String ?? ""
      if nid == "easy_cook" {
        lines.append(t(language, "easy_cook"))
      } else if nid == "over_calories" {
        lines.append(t(language, "over_note"))
      }
    }
    return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
  }

  private static func foodLine(_ lang: String, _ item: [String: Any]) -> String {
    let food = item["food"] as? String ?? ""
    let name = t(lang, food)
    let lo = item["lo"] as? Int ?? 0
    let hi = item["hi"] as? Int ?? 0
    let amount = amountText(lang, lo, hi)
    var extra = ""
    if item["suffix"] as? String == "max" {
      extra = " " + t(lang, "max_word")
    }
    var line: String
    if let orFood = item["or_food"] as? String {
      let altAmt = amountText(lang, item["or_lo"] as? Int ?? 0, item["or_hi"] as? Int ?? 0)
      line = "\(name): \(amount)\(extra) \(t(lang, "or_word")) \(lowerFirst(t(lang, orFood))): \(altAmt)"
    } else if !amount.isEmpty {
      line = "\(name): \(amount)\(extra)"
    } else {
      line = name
    }
    if item["optional_carbs"] as? Bool == true {
      line = "\(name): ½–1 (\(amount)) \(t(lang, "banana_if"))"
    }
    return line
  }

  private static func lowerFirst(_ s: String) -> String {
    guard let first = s.first else { return s }
    return String(first).lowercased() + s.dropFirst()
  }

  private static func amountText(_ lang: String, _ lo: Int, _ hi: Int) -> String {
    let unit = t(lang, "g_unit")
    if lo <= 0 && hi <= 0 { return "" }
    if lo == hi { return "\(lo) \(unit)" }
    return "\(lo)–\(hi) \(unit)"
  }

  private static func t(_ lang: String, _ key: String, _ vars: [String: Int] = [:]) -> String {
    var s = Strings.shared.value(lang, key)
    for (k, v) in vars {
      s = s.replacingOccurrences(of: "{\(k)}", with: String(v))
    }
    return s
  }

  private final class Strings {
    static let shared = Strings()
    private let table: [String: [String: String]]
    private init() {
      if let url = Bundle.main.url(forResource: "meal_planner_i18n", withExtension: "json")
        ?? Bundle.main.url(forResource: "meal_planner_i18n", withExtension: "json", subdirectory: "Resources"),
        let data = try? Data(contentsOf: url),
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: [String: String]]
      {
        table = obj
      } else {
        table = [:]
      }
    }

    func value(_ lang: String, _ key: String) -> String {
      let code = lang.split(separator: "-").first.map(String.init)?.lowercased() ?? "en"
      if let v = table[code]?[key] { return v }
      if let v = table["en"]?[key] { return v }
      return key
    }
  }
}
