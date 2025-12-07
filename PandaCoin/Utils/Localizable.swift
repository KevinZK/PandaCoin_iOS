//
//  Localizable.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import Foundation

enum L10n {
    // MARK: - Common
    enum Common {
        static let appName = "app_name".localized
        static let confirm = "common_confirm".localized
        static let cancel = "common_cancel".localized
        static let save = "common_save".localized
        static let delete = "common_delete".localized
        static let edit = "common_edit".localized
        static let add = "common_add".localized
        static let close = "common_close".localized
        static let loading = "common_loading".localized
        static let done = "common_done".localized
        static let search = "common_search".localized
        static let all = "common_all".localized
    }
    
    // MARK: - Auth
    enum Auth {
        static let login = "auth_login".localized
        static let register = "auth_register".localized
        static let logout = "auth_logout".localized
        static let email = "auth_email".localized
        static let password = "auth_password".localized
        static let confirmPassword = "auth_confirm_password".localized
        static let name = "auth_name".localized
        static let welcomeBack = "auth_welcome_back".localized
        static let createAccount = "auth_create_account".localized
        static let emailPlaceholder = "auth_email_placeholder".localized
        static let passwordPlaceholder = "auth_password_placeholder".localized
        static let namePlaceholder = "auth_name_placeholder".localized
        static let noAccount = "auth_no_account".localized
        static let hasAccount = "auth_has_account".localized
    }
    
    // MARK: - TabBar
    enum TabBar {
        static let home = "tab_home".localized
        static let records = "tab_records".localized
        static let statistics = "tab_statistics".localized
        static let accounts = "tab_accounts".localized
        static let budget = "tab_budget".localized
        static let settings = "tab_settings".localized
    }
    
    // MARK: - Dashboard
    enum Dashboard {
        static let totalAssets = "dashboard_total_assets".localized
        static let netAssets = "dashboard_net_assets".localized
        static let monthIncome = "dashboard_month_income".localized
        static let monthExpense = "dashboard_month_expense".localized
        static let budgetProgress = "dashboard_budget_progress".localized
        static let quickActions = "dashboard_quick_actions".localized
        static let recentRecords = "dashboard_recent_records".localized
        static let viewAll = "dashboard_view_all".localized
    }
    
    // MARK: - Voice
    enum Voice {
        static let voiceRecord = "voice_record".localized
        static let listening = "voice_listening".localized
        static let tapToRecord = "voice_tap_to_record".localized
        static let holdToSpeak = "voice_hold_to_speak".localized
        static let confirmRecords = "voice_confirm_records".localized
        static let pandaSays = "voice_panda_says".localized
    }
    
    // MARK: - Account
    enum Account {
        static let accountManagement = "account_management".localized
        static let addAccount = "account_add".localized
        static let editAccount = "account_edit".localized
        static let accountName = "account_name".localized
        static let accountType = "account_type".localized
        static let balance = "account_balance".localized
        static let initialBalance = "account_initial_balance".localized
        static let currentBalance = "account_current_balance".localized
        static let deleteAccount = "account_delete".localized
        static let deleteConfirm = "account_delete_confirm".localized
        static let noAccounts = "account_no_accounts".localized
        static let addAccountHint = "account_add_hint".localized
        
        // Account Types
        static let typeBank = "account_type_bank".localized
        static let typeInvestment = "account_type_investment".localized
        static let typeCash = "account_type_cash".localized
        static let typeCreditCard = "account_type_credit_card".localized
        static let typeDigitalWallet = "account_type_digital_wallet".localized
        static let typeLoan = "account_type_loan".localized
        static let typeMortgage = "account_type_mortgage".localized
        static let typeSavings = "account_type_savings".localized
        static let typeRetirement = "account_type_retirement".localized
        static let typeCrypto = "account_type_crypto".localized
        static let typeProperty = "account_type_property".localized
        static let typeVehicle = "account_type_vehicle".localized
        static let typeOtherAsset = "account_type_other_asset".localized
        static let typeOtherLiability = "account_type_other_liability".localized
    }
    
    // MARK: - Record
    enum Record {
        static let records = "record_records".localized
        static let addRecord = "record_add".localized
        static let manualRecord = "record_manual".localized
        static let type = "record_type".localized
        static let amount = "record_amount".localized
        static let category = "record_category".localized
        static let description = "record_description".localized
        static let date = "record_date".localized
        static let noRecords = "record_no_records".localized
        static let startRecording = "record_start_hint".localized
        
        // Record Types
        static let expense = "record_type_expense".localized
        static let income = "record_type_income".localized
        static let transfer = "record_type_transfer".localized
        
        // Categories - Expense
        static let categoryFood = "category_food".localized
        static let categoryTransport = "category_transport".localized
        static let categoryShopping = "category_shopping".localized
        static let categoryEntertainment = "category_entertainment".localized
        static let categoryMedical = "category_medical".localized
        static let categoryHousing = "category_housing".localized
        static let categoryEducation = "category_education".localized
        static let categoryCommunication = "category_communication".localized
        static let categorySports = "category_sports".localized
        static let categoryBeauty = "category_beauty".localized
        static let categoryTravel = "category_travel".localized
        static let categoryOther = "category_other".localized
        
        // Categories - Income
        static let categorySalary = "category_salary".localized
        static let categoryBonus = "category_bonus".localized
        static let categoryInvestment = "category_investment".localized
        static let categoryParttime = "category_parttime".localized
    }
    
    // MARK: - Statistics
    enum Statistics {
        static let statistics = "statistics_title".localized
        static let thisMonth = "statistics_this_month".localized
        static let thisYear = "statistics_this_year".localized
        static let totalIncome = "statistics_total_income".localized
        static let totalExpense = "statistics_total_expense".localized
        static let netIncome = "statistics_net_income".localized
        static let expenseDistribution = "statistics_expense_distribution".localized
        static let expenseRanking = "statistics_expense_ranking".localized
        static let noData = "statistics_no_data".localized
    }
    
    // MARK: - Settings
    enum Settings {
        static let settings = "settings_title".localized
        static let language = "settings_language".localized
        static let currency = "settings_currency".localized
        static let theme = "settings_theme".localized
        static let about = "settings_about".localized
        static let languageHint = "settings_language_hint".localized
    }
    
    // MARK: - Language Names
    enum Language {
        static let system = "language_system".localized
        static let chinese = "language_chinese".localized
        static let english = "language_english".localized
        static let japanese = "language_japanese".localized
        static let korean = "language_korean".localized
        static let german = "language_german".localized
        static let french = "language_french".localized
        static let spanish = "language_spanish".localized
    }
    
    // MARK: - Errors
    enum Error {
        static let invalidEmail = "error_invalid_email".localized
        static let passwordTooShort = "error_password_too_short".localized
        static let passwordMismatch = "error_password_mismatch".localized
        static let networkError = "error_network".localized
        static let unknownError = "error_unknown".localized
    }
}

// MARK: - String Extension
extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}
