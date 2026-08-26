import Testing
@testable import MyFitnessPal_Dupe

struct NutritionLabelParserTests {
    @Test func wrapLabelUsesPer100gProteinAndServingSize() {
        let text = """
        Typical values Per 100g Per Wrap (62g)
        Energy 272 kcal 169 kcal
        Fat 5.8g 3.6g
        Carbohydrate 49g 30.4g
        Protein 6.8g 4.2g
        """

        let result = NutritionLabelParser.parse(text)

        #expect(result.calories == 272)
        #expect(result.protein == 6.8)
        #expect(result.carbs == 49)
        #expect(result.fat == 5.8)
        #expect(result.servingSizeGrams == 62)
    }

    @Test func servingColumnFirstStillUsesPer100gValues() {
        let text = """
        Typical values Per 40g serving Per 100g
        Energy 62 kcal 155 kcal
        Fat 1.1g 2.8g
        Carbohydrate 20g 50g
        Protein 3.2g 8g
        """

        let result = NutritionLabelParser.parse(text)

        #expect(result.calories == 155)
        #expect(result.protein == 8)
        #expect(result.carbs == 50)
        #expect(result.fat == 2.8)
        #expect(result.servingSizeGrams == 40)
    }

    @Test func ignoresSugarRowsAndKeepsBareSecondColumnNumbers() {
        let text = """
        Typical values Per 40g serving Per 100g
        Energy 80 kcal 200
        Fat 0.4g 1.4
        Carbohydrate 12g 49
        of which sugars 8g 22g
        Protein 2.7g 6.8
        """

        let result = NutritionLabelParser.parse(text)

        #expect(result.calories == 200)
        #expect(result.protein == 6.8)
        #expect(result.carbs == 49)
        #expect(result.fat == 1.4)
        #expect(result.servingSizeGrams == 40)
    }

    @Test func energyUsesKcalAndMergedSubRowsDoNotPolluteMacros() {
        let text = """
        Typical values Per 40g serving Per 100g
        Energy kJ kcal 335 80 837 200
        Fat 0.4g 1.7 saturates 0.1g 0.3g
        Carbohydrate 12g 49 of which sugars 8g 22g
        Protein 2.7g 6.8 Salt 0.3g 1.1g
        """

        let result = NutritionLabelParser.parse(text)

        #expect(result.calories == 200)
        #expect(result.protein == 6.8)
        #expect(result.carbs == 49)
        #expect(result.fat == 1.7)
        #expect(result.servingSizeGrams == 40)
    }
}
