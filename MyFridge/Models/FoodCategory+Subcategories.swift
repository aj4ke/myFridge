import Foundation

nonisolated extension FoodCategory {
    var subcategories: [String] {
        switch self {
        case .dairyMilk: ["Whole", "2%", "1%", "Skim", "Oat", "Almond", "Soy", "Half & Half", "Heavy Cream"]
        case .dairyMilkUltra: ["Whole", "2%", "1%", "Skim", "Lactose-Free", "Half & Half", "Heavy Cream"]
        case .dairyYogurt: ["Greek", "Regular", "Skyr", "Kefir"]
        case .cheeseHard: ["Cheddar", "Parmesan", "Swiss", "Gouda", "Monterey Jack", "Provolone", "Pecorino"]
        case .cheeseSoft: ["Mozzarella", "Brie", "Goat", "Feta", "Ricotta", "Cream Cheese", "Cottage Cheese", "Burrata"]
        case .eggs: []
        case .meatRaw: [
            "Flank Steak", "Filet Mignon", "T-Bone Steak", "Strip Steak", "Ribeye Steak", "Sirloin Steak",
            "Skirt Steak", "Ground Beef", "Beef Roast", "Stew Beef", "Pork Chops", "Pork Tenderloin",
            "Ground Pork", "Bacon", "Sausage", "Lamb",
        ]
        case .poultryRaw: [
            "Chicken Breast", "Chicken Thighs", "Chicken Wings", "Drumsticks", "Whole Chicken",
            "Ground Chicken", "Ground Turkey", "Turkey Breast",
        ]
        case .seafoodRaw: ["Salmon", "Shrimp", "Cod", "Tuna", "Tilapia", "Halibut", "Scallops", "Crab", "Mussels"]
        case .meatDeli: ["Turkey", "Ham", "Roast Beef", "Chicken", "Salami", "Prosciutto", "Pepperoni", "Bologna"]
        case .produceLeafy: ["Spinach", "Lettuce", "Kale", "Arugula", "Spring Mix", "Chard", "Bok Choy"]
        case .produceBerries: ["Strawberries", "Blueberries", "Raspberries", "Blackberries"]
        case .produceOther: [
            "Broccoli", "Carrots", "Bell Peppers", "Cucumber", "Zucchini", "Mushrooms", "Celery",
            "Green Beans", "Asparagus", "Cauliflower",
        ]
        case .fruitWhole: ["Apples", "Oranges", "Grapes", "Lemons", "Limes", "Pears", "Peaches", "Plums"]
        case .herbs: ["Cilantro", "Parsley", "Basil", "Mint", "Dill", "Rosemary", "Thyme", "Chives"]
        case .tofuTempeh: ["Firm Tofu", "Extra-Firm Tofu", "Silken Tofu", "Tempeh"]
        case .preparedMeals: ["Salad", "Soup", "Sandwich", "Sushi", "Pasta", "Rotisserie Chicken"]
        case .leftovers: []
        case .condiments: ["Ketchup", "Mustard", "Mayo", "Salsa", "Hot Sauce", "Salad Dressing", "Jam", "Pickles", "Hummus"]
        case .beverages: ["Juice", "Soda", "Sparkling Water", "Beer", "Wine", "Kombucha", "Cold Brew"]
        case .breadBakery: ["Sandwich Bread", "Bagels", "Tortillas", "Buns & Rolls", "English Muffins", "Pita", "Muffins", "Pastries"]
        case .grainsPasta: ["Pasta", "Rice", "Quinoa", "Oats", "Noodles", "Couscous", "Dried Beans", "Lentils"]
        case .cannedGoods: ["Soup", "Beans", "Tomatoes", "Tuna", "Vegetables", "Fruit", "Broth", "Pasta Sauce"]
        case .snacksCereal: ["Cereal", "Granola", "Chips", "Crackers", "Pretzels", "Popcorn", "Nuts", "Cookies", "Snack Bars", "Dried Fruit"]
        case .bakingSpices: ["Flour", "Sugar", "Spices", "Oil", "Baking Soda", "Baking Powder", "Yeast", "Vanilla", "Honey", "Syrup"]
        case .frozenMeals: ["Pizza", "Waffles", "Fries", "Dinners", "Burritos", "Nuggets", "Dumplings", "Breakfast Sandwiches"]
        case .frozenProduce: ["Mixed Vegetables", "Peas", "Corn", "Broccoli", "Spinach", "Berries", "Mango", "Edamame"]
        case .frozenDesserts: ["Ice Cream", "Sorbet", "Popsicles", "Frozen Yogurt", "Ice Cream Bars"]
        case .other: []
        }
    }
}
