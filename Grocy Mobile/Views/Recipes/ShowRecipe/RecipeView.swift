//
//  RecipeView.swift
//  Grocy Mobile
//
//  Created by Georg Meissner on 23.11.23.
//

import SwiftData
import SwiftUI
import WebKit

struct RecipeView: View {
    @Environment(GrocyViewModel.self) private var grocyVM
    @Environment(\.modelContext) private var modelContext

    @Query var mdQuantityUnits: MDQuantityUnits

    var recipe: Recipe

    @State private var page = WebPage()
    let blank = URL(string: "about:blank")!

    @State private var desiredServings: Double = 1.0

    private let dataToUpdate: [ObjectEntities] = [.quantity_units, .recipes_pos_resolved]
    private let additionalDataToUpdate: [AdditionalEntities] = []
    private func updateData() async {
        await grocyVM.requestData(objects: dataToUpdate, additionalObjects: additionalDataToUpdate)
    }

    var recipes: [RecipePosResolvedElement] {
        let sortDescriptor = SortDescriptor<RecipePosResolvedElement>(\.ingredientGroup)
        let predicate = #Predicate<RecipePosResolvedElement> { recipePos in
            recipePos.recipeID == recipe.id
        }

        let descriptor = FetchDescriptor<RecipePosResolvedElement>(
            predicate: predicate,
            sortBy: [sortDescriptor]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    var groupedRecipes: [String: [RecipePosResolvedElement]] {
        var groupedRecipes: [String: [RecipePosResolvedElement]] = [:]
        for recipePos in recipes {
            let ingredientGroup = recipePos.ingredientGroup ?? ""
            if groupedRecipes[ingredientGroup] == nil {
                groupedRecipes[ingredientGroup] = []
            }
            groupedRecipes[ingredientGroup]?.append(recipePos)
        }
        return groupedRecipes
    }

    var posResCount: Int {
        var descriptor = FetchDescriptor<RecipePosResolvedElement>(
            sortBy: []
        )
        descriptor.fetchLimit = 0

        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    var summedCalories: Double {
        var sumOfCalories: Double = 0

        for recipe in recipes {
            sumOfCalories += recipe.calories
        }

        return sumOfCalories
    }

    var summedPrice: Double {
        var sumOfPrice: Double = 0

        for recipe in recipes {
            sumOfPrice += recipe.costs
        }

        return sumOfPrice
    }
    var noPriceForOne: Bool {
        var noPrice: Bool = false
        for recipe in recipes {
            if recipe.costs.isZero {
                noPrice = true
            }
        }
        return noPrice
    }

    var body: some View {
        //        ScrollView(.vertical) {
        //            VStack(alignment: .leading) {
        //                if let pictureFileName = recipe.pictureFileName {
        //                    PictureView(pictureFileName: pictureFileName, pictureType: .recipePictures)
        //                        .backgroundExtensionEffect()
        //                }

        List {
            Section {
                //                MyDoubleStepper(amount: $recipe.desiredServings, description: "Desired servings", systemImage: MySymbols.amount)
                LabeledContent(
                    content: {
                        Text("\(summedCalories.formattedAmount) kcal")
                    },
                    label: {
                        Label(
                            title: {
                                HStack {
                                    Text("Energy")
                                    FieldDescription(description: "per serving")
                                }
                            },
                            icon: {
                                Image(systemName: MySymbols.energy)
                            }
                        )
                    }
                )
                .foregroundStyle(.primary)
                VStack(alignment: .leading, spacing: 5.0) {
                    LabeledContent(
                        content: {
                            Text(grocyVM.getFormattedCurrency(amount: summedPrice))
                        },
                        label: {
                            Label(title: {
                                HStack {
                                    Text("Costs")
                                    FieldDescription(description: "Based on the prices of the default consume rule (Opened first, then first due first, then first in first out) for in stock ingredients and on the last price for missing ones")
                                }
                            }, icon: {
                                Image(systemName: MySymbols.price)
                            })
                        }
                    )
                    .foregroundStyle(.primary)
                    if noPriceForOne {
                        Text("No price information is available for at least one ingredient")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            Section("Ingredients") {
                ForEach(groupedRecipes.sorted(by: { $0.key < $1.key }), id: \.key) { (groupName, recipes) in
                    Section {
                        ForEach(recipes, id: \.id) { recipe in
                            RecipeIngredientRowView(recipePos: recipe, quantityUnit: mdQuantityUnits.first(where: { $0.id == recipe.quID }))
                        }
                    } header: {
                        if !groupName.isEmpty {
                            Text(groupName)
                                .font(.headline)
                                .italic()
                        }
                    }
                }
            }
            Section(
                "Preparation",
                content: {
                    WebView(page)
                        .aspectRatio(contentMode: .fit)
                        .onAppear {
                            page.load(html: recipe.recipeDescription, baseURL: blank)
                        }
                }
            )
        }
        .navigationTitle(recipe.name)
        .task {
            await updateData()
        }
    }
}

#Preview {
    NavigationStack {
        RecipeView(recipe: Recipe(name: "Recipe 1", recipeDescription: "<h1>Hello</h1>"))
    }
}
