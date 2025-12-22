import SwiftUI
import Combine

class BudgetViewModel: ObservableObject {
    @Published var summary: MonthlyBudgetSummary?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentMonth: String
    
    private var cancellables = Set<AnyCancellable>()
    private let networkManager = NetworkManager.shared
    
    init() {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        self.currentMonth = formatter.string(from: now)
    }
    
    // MARK: - 获取当月预算进度
    func fetchCurrentProgress() {
        isLoading = true
        errorMessage = nil
        
        networkManager.request(
            endpoint: "/budgets/progress/current",
            method: "GET"
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] (completion: Subscribers.Completion<APIError>) in
            self?.isLoading = false
            if case .failure(let error) = completion {
                self?.errorMessage = error.localizedDescription
            }
        } receiveValue: { [weak self] (summary: MonthlyBudgetSummary) in
            self?.summary = summary
            self?.currentMonth = summary.month
        }
        .store(in: &cancellables)
    }
    
    // MARK: - 获取指定月份预算进度
    func fetchProgress(for month: String) {
        isLoading = true
        errorMessage = nil
        currentMonth = month
        
        networkManager.request(
            endpoint: "/budgets/progress/\(month)",
            method: "GET"
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] (completion: Subscribers.Completion<APIError>) in
            self?.isLoading = false
            if case .failure(let error) = completion {
                self?.errorMessage = error.localizedDescription
            }
        } receiveValue: { [weak self] (summary: MonthlyBudgetSummary) in
            self?.summary = summary
        }
        .store(in: &cancellables)
    }
    
    // MARK: - 创建预算
    func createBudget(category: String?, amount: Double, isRecurring: Bool = false, completion: @escaping (Bool) -> Void) {
        let request = CreateBudgetRequest(
            month: currentMonth,
            category: category,
            amount: amount,
            isRecurring: isRecurring
        )
        
        networkManager.request(
            endpoint: "/budgets",
            method: "POST",
            body: request
        )
        .receive(on: DispatchQueue.main)
        .sink { (result: Subscribers.Completion<APIError>) in
            if case .failure = result {
                completion(false)
            }
        } receiveValue: { [weak self] (_: Budget) in
            completion(true)
            self?.fetchProgress(for: self?.currentMonth ?? "")
        }
        .store(in: &cancellables)
    }
    
    // MARK: - 更新预算
    func updateBudget(id: String, amount: Double, isRecurring: Bool? = nil, completion: @escaping (Bool) -> Void) {
        let request = UpdateBudgetRequest(amount: amount, isRecurring: isRecurring)
        
        networkManager.request(
            endpoint: "/budgets/\(id)",
            method: "PUT",
            body: request
        )
        .receive(on: DispatchQueue.main)
        .sink { (result: Subscribers.Completion<APIError>) in
            if case .failure = result {
                completion(false)
            }
        } receiveValue: { [weak self] (_: Budget) in
            completion(true)
            self?.fetchProgress(for: self?.currentMonth ?? "")
        }
        .store(in: &cancellables)
    }
    
    // MARK: - 删除预算（仅删除当月）
    func deleteBudget(id: String, completion: @escaping (Bool) -> Void) {
        networkManager.request(
            endpoint: "/budgets/\(id)",
            method: "DELETE"
        )
        .receive(on: DispatchQueue.main)
        .sink { (result: Subscribers.Completion<APIError>) in
            if case .failure = result {
                completion(false)
            }
        } receiveValue: { [weak self] (_: EmptyResponse) in
            completion(true)
            self?.fetchProgress(for: self?.currentMonth ?? "")
        }
        .store(in: &cancellables)
    }
    
    // MARK: - 取消循环预算（删除当月及所有未来月份）
    func cancelRecurringBudget(id: String, completion: @escaping (Bool) -> Void) {
        networkManager.request(
            endpoint: "/budgets/\(id)/cancel-recurring",
            method: "DELETE"
        )
        .receive(on: DispatchQueue.main)
        .sink { (result: Subscribers.Completion<APIError>) in
            if case .failure = result {
                completion(false)
            }
        } receiveValue: { [weak self] (_: CancelRecurringResponse) in
            completion(true)
            self?.fetchProgress(for: self?.currentMonth ?? "")
        }
        .store(in: &cancellables)
    }
    
    // MARK: - 复制上月预算
    func copyFromPreviousMonth(completion: @escaping (Int) -> Void) {
        networkManager.request(
            endpoint: "/budgets/copy-from-previous",
            method: "POST"
        )
        .receive(on: DispatchQueue.main)
        .sink { (result: Subscribers.Completion<APIError>) in
            if case .failure = result {
                completion(0)
            }
        } receiveValue: { [weak self] (response: CopyBudgetResponse) in
            completion(response.copiedCount)
            self?.fetchProgress(for: self?.currentMonth ?? "")
        }
        .store(in: &cancellables)
    }
    
    // MARK: - 切换月份
    func previousMonth() {
        if let date = monthToDate(currentMonth) {
            let newDate = Calendar.current.date(byAdding: .month, value: -1, to: date)!
            currentMonth = dateToMonth(newDate)
            fetchProgress(for: currentMonth)
        }
    }
    
    func nextMonth() {
        if let date = monthToDate(currentMonth) {
            let newDate = Calendar.current.date(byAdding: .month, value: 1, to: date)!
            currentMonth = dateToMonth(newDate)
            fetchProgress(for: currentMonth)
        }
    }
    
    private func monthToDate(_ month: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.date(from: month)
    }
    
    private func dateToMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
    
    // 格式化月份显示
    var displayMonth: String {
        if let date = monthToDate(currentMonth) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年M月"
            return formatter.string(from: date)
        }
        return currentMonth
    }
}

// MARK: - Helper Types
struct CopyBudgetResponse: Codable {
    let copiedCount: Int
}

struct CancelRecurringResponse: Codable {
    let deletedCount: Int
}
