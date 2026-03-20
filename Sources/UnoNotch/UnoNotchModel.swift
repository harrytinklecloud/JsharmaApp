import AppKit
import Foundation
import SwiftUI

enum ReceptionSection: String, CaseIterable, Identifiable {
    case overview
    case inbox
    case schedule
    case automations

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Front Desk"
        case .inbox: "Lead Inbox"
        case .schedule: "Today"
        case .automations: "Flows"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: "sparkles.rectangle.stack.fill"
        case .inbox: "message.badge.fill"
        case .schedule: "calendar.badge.clock"
        case .automations: "bolt.badge.automatic.fill"
        }
    }
}

struct ActivityMessage: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
    let timestamp: Date
}

struct PipelineMetric: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let delta: String
    let tint: Color
}

struct LeadConversation: Identifiable {
    let id = UUID()
    let customerName: String
    let channel: String
    let summary: String
    let requestedService: String
    let priority: String
    let etaText: String
    let lastMessagePreview: String
    let readyToBook: Bool
    let accent: Color
}

struct AppointmentCard: Identifiable {
    let id = UUID()
    let time: String
    let customerName: String
    let service: String
    let assignee: String
    let status: String
}

struct WorkflowCard: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let liveCount: String
    let status: String
}

@MainActor
final class UnoNotchModel: ObservableObject {
    static let shared = UnoNotchModel()

    @Published var isExpanded = false
    @Published var hoverExpansionEnabled = true
    @Published var hideUntilHover = true
    @Published var autoCollapseDelay = 0.45
    @Published var soundEffectsEnabled = true
    @Published var autoReplyEnabled = true
    @Published var activeSection: ReceptionSection = .overview
    @Published var businessName = "Northstar Dental"
    @Published var welcomeLine = "AI receptionist for missed calls, texts, and bookings"
    @Published var pipelineMetrics: [PipelineMetric] = []
    @Published var conversations: [LeadConversation] = []
    @Published var appointments: [AppointmentCard] = []
    @Published var workflows: [WorkflowCard] = []
    @Published var activityFeed: [ActivityMessage] = []
    @Published var avgReplyTime = "38 sec"
    @Published var bookedToday = 11
    @Published var revenueRecovered = "$4,860"

    init() {
        seedDemoData()
    }

    var heroTitle: String {
        switch activeSection {
        case .overview:
            return businessName
        case .inbox:
            return conversations.first?.customerName ?? "Lead Inbox"
        case .schedule:
            return "Today's Appointments"
        case .automations:
            return "Follow-up Flows"
        }
    }

    var heroSummary: String {
        switch activeSection {
        case .overview:
            return "\(bookedToday) bookings today, \(avgReplyTime) avg response, \(revenueRecovered) recovered"
        case .inbox:
            return "New leads are triaged, qualified, and routed without a human sitting on the phone."
        case .schedule:
            return "\(appointments.count) appointments lined up with automatic reminders and no-show protection."
        case .automations:
            return "Automations keep leads warm after hours and push qualified conversations to booking."
        }
    }

    var nextRecommendedAction: String {
        if let urgent = conversations.first(where: { $0.priority == "Urgent" }) {
            return "Call \(urgent.customerName) now"
        }
        return "Keep auto-replies live"
    }

    func toggleExpanded() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            isExpanded.toggle()
        }
    }

    func prepareForReveal(force _: Bool = false) {
        if pipelineMetrics.isEmpty {
            seedDemoData()
        }
    }

    func focusInbox() {
        activeSection = .inbox
        pushActivity(title: "Inbox opened", symbol: "message.fill")
    }

    func focusSchedule() {
        activeSection = .schedule
        pushActivity(title: "Schedule reviewed", symbol: "calendar")
    }

    func focusAutomations() {
        activeSection = .automations
        pushActivity(title: "Automations checked", symbol: "bolt.fill")
    }

    func triggerInstantReply() {
        guard let lead = conversations.first else { return }
        pushActivity(title: "Auto-replied to \(lead.customerName)", symbol: "paperplane.fill")
    }

    func bookTopLead() {
        guard !conversations.isEmpty else { return }
        let lead = conversations.removeFirst()
        appointments.insert(
            AppointmentCard(
                time: "4:30 PM",
                customerName: lead.customerName,
                service: lead.requestedService,
                assignee: "Dr. Singh",
                status: "Booked"
            ),
            at: 0
        )
        bookedToday += 1
        revenueRecovered = "$5,240"
        pushActivity(title: "Booked \(lead.customerName)", symbol: "checkmark.circle.fill")
    }

    func toggleAutoReply() {
        autoReplyEnabled.toggle()
        pushActivity(
            title: autoReplyEnabled ? "Auto-replies enabled" : "Auto-replies paused",
            symbol: autoReplyEnabled ? "bolt.badge.checkmark" : "pause.circle.fill"
        )
    }

    private func seedDemoData() {
        pipelineMetrics = [
            PipelineMetric(label: "Missed calls saved", value: "27", delta: "+18%", tint: .green),
            PipelineMetric(label: "Booked from text", value: "11", delta: "+6 today", tint: .blue),
            PipelineMetric(label: "Qualified leads", value: "19", delta: "74% rate", tint: .orange),
            PipelineMetric(label: "Revenue recovered", value: "$4.8k", delta: "This week", tint: .pink)
        ]

        conversations = [
            LeadConversation(
                customerName: "Maya Chen",
                channel: "Missed Call",
                summary: "Asked about same-day emergency cleaning for tooth pain.",
                requestedService: "Emergency exam",
                priority: "Urgent",
                etaText: "Needs response in 4 min",
                lastMessagePreview: "Can someone see me before 5? I'm in a lot of pain.",
                readyToBook: true,
                accent: .red
            ),
            LeadConversation(
                customerName: "Ethan Brooks",
                channel: "SMS",
                summary: "Wanted Invisalign pricing and insurance check.",
                requestedService: "Consultation",
                priority: "Warm",
                etaText: "Follow up this hour",
                lastMessagePreview: "If insurance helps, I'd like to come in next week.",
                readyToBook: true,
                accent: .blue
            ),
            LeadConversation(
                customerName: "Sofia Patel",
                channel: "Web Chat",
                summary: "Asking if Saturday appointments are still open.",
                requestedService: "Cleaning",
                priority: "New",
                etaText: "Auto follow-up queued",
                lastMessagePreview: "Saturday morning would be perfect if you have anything.",
                readyToBook: false,
                accent: .teal
            )
        ]

        appointments = [
            AppointmentCard(time: "2:00 PM", customerName: "Jordan Lee", service: "Whitening consult", assignee: "Dr. Singh", status: "Confirmed"),
            AppointmentCard(time: "3:15 PM", customerName: "Ava Nguyen", service: "Cavity filling", assignee: "Dr. Singh", status: "Reminder sent"),
            AppointmentCard(time: "4:00 PM", customerName: "Liam Carter", service: "Cleaning", assignee: "Hygiene Team", status: "Waiting on intake")
        ]

        workflows = [
            WorkflowCard(name: "After-hours rescue", description: "Texts every missed caller, asks symptom urgency, offers the next open slot.", liveCount: "8 running", status: "Healthy"),
            WorkflowCard(name: "Insurance qualification", description: "Collects provider info, checks plan type, and tags cash-pay fallbacks.", liveCount: "5 waiting", status: "Healthy"),
            WorkflowCard(name: "No-show recovery", description: "Sends a soft reminder, then a rebook link 20 minutes after a missed appointment.", liveCount: "2 delayed", status: "Needs review")
        ]

        activityFeed = [
            ActivityMessage(title: "Recovered a missed call from Maya Chen", symbol: "phone.badge.checkmark", timestamp: .now.addingTimeInterval(-120)),
            ActivityMessage(title: "Booked whitening consult from SMS", symbol: "calendar.badge.plus", timestamp: .now.addingTimeInterval(-860)),
            ActivityMessage(title: "Tagged high-intent Invisalign lead", symbol: "sparkles", timestamp: .now.addingTimeInterval(-1800))
        ]
    }

    private func pushActivity(title: String, symbol: String) {
        activityFeed.insert(ActivityMessage(title: title, symbol: symbol, timestamp: .now), at: 0)
        if activityFeed.count > 6 {
            activityFeed = Array(activityFeed.prefix(6))
        }
    }
}
