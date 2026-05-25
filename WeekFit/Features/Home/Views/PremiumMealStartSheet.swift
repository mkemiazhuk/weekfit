//import SwiftUI
//import SwiftData
//
//struct PremiumMealStartSheet: View {
//    // Получаем окружения от родителя для синхронизации контекстов
//    let background: Color
//    let cardBackground: Color
//    let textSecondary: Color
//    
//    @Binding var isPresented: Bool
//    @Binding var refreshID: UUID
//    @Binding var selectedTab: WeekFitTab
//    
//    var modelContext: any SwiftData.ModelContext
//    
//    // Читаем базу кастомных рецептов напрямую из UserDefaults
//    private var decodedMeals: [Meals] {
//        let storedData = UserDefaults.standard.string(forKey: "weekfit_custom_meals_v1") ?? ""
//        guard let data = storedData.data(using: .utf8) else { return [] }
//        return (try? JSONDecoder().decode([Meals].self, from: data)) ?? []
//    }
//    
//    var body: some View {
//        NavigationStack {
//            ZStack {
//                background.ignoresSafeArea()
//                
//                if decodedMeals.isEmpty {
//                    // Премиальный пустой стейт, если рецептов нет
//                    VStack(spacing: 20) {
//                        Image(systemName: "fork.knife.circle.fill")
//                            .font(.system(size: 48, weight: .light))
//                            .foregroundColor(Color(red: 0.16, green: 0.80, blue: 0.43).opacity(0.4))
//                        
//                        VStack(spacing: 6) {
//                            Text("No custom meals saved yet")
//                                .font(.system(size: 16, weight: .semibold))
//                                .foregroundColor(.white)
//                            Text("Build your recipes library to enable instant logging updates.")
//                                .font(.system(size: 13))
//                                .foregroundColor(textSecondary.opacity(0.7))
//                                .multilineTextAlignment(.center)
//                                .padding(.horizontal, 32)
//                        }
//                        
//                        Button {
//                            isPresented = false
//                            // Плавный переход в главное меню рецептов
//                            withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
//                                selectedTab = .meals
//                            }
//                        } label: {
//                            Text("Open Meal Planner")
//                                .font(.system(size: 14, weight: .bold))
//                                .foregroundColor(Color(red: 0.16, green: 0.80, blue: 0.43))
//                                .padding(.horizontal, 20)
//                                .frame(height: 36)
//                                .background(Color(red: 0.16, green: 0.80, blue: 0.43).opacity(0.1))
//                                .clipShape(Capsule())
//                        }
//                        .buttonStyle(.plain)
//                    }
//                    .padding(.bottom, 40)
//                } else {
//                    // Используем наши новые вынесенные Premium-карточки!
//                    ScrollView(showsIndicators: false) {
//                        VStack(spacing: 14) {
//                            ForEach(decodedMeals) { meal in
//                                PremiumActivityStartCard(
//                                    title: meal.title,
//                                    subtitle: "\(meal.calories) kcal • P \(meal.protein)g",
//                                    systemIcon: "fork.knife",
//                                    accentColor: Color(red: 0.55, green: 0.40, blue: 0.85), // Твой mealAccent
//                                    cardBackground: cardBackground,
//                                    textSecondary: textSecondary
//                                ) {
//                                    // Мгновенный лог-экшен еды (isCompleted = true, в отличие от тренировок)
//                                    let quickLogActivity = PlannedActivity(
//                                        id: UUID().uuidString,
//                                        date: Date(),
//                                        type: "meal",
//                                        title: meal.title,
//                                        durationMinutes: 20,
//                                        icon: "fork.knife",
//                                        imageName: meal.imageName,
//                                        colorRed: 0.55, colorGreen: 0.40, colorBlue: 0.85,
//                                        calories: meal.calories,
//                                        protein: meal.protein,
//                                        carbs: meal.carbs,
//                                        fats: meal.fats,
//                                        isCompleted: true, // Еда падает сразу залогированной
//                                        isSkipped: false
//                                    )
//                                    
//                                    modelContext.insert(quickLogActivity)
//                                    try? modelContext.save()
//                                    
//                                    isPresented = false
//                                    refreshID = UUID() // Обновляем кольца на главном экране
//                                }
//                            }
//                        }
//                        .padding(16)
//                    }
//                }
//            }
//            .navigationTitle("Log Meal")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button("Close") { isPresented = false }
//                        .font(.system(size: 14, weight: .bold))
//                        .foregroundColor(.gray)
//                }
//            }
//        }
//    }
//}
