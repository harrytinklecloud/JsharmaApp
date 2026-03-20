import AppKit
import SwiftUI

struct FloatingIslandRootView: View {
    @ObservedObject var model: UnoNotchModel
    @State private var notchMetrics = NotchMetrics.current()
    @State private var hoverCloseTask: Task<Void, Never>?
    @State private var isPointerInTrigger = false
    @State private var isPointerInTray = false

    private let panelWidth: CGFloat = 840
    private let panelHeight: CGFloat = 560

    private var triggerWidth: CGFloat {
        notchMetrics.hardwareWidth + 16
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear

            VStack(spacing: 0) {
                Capsule(style: .continuous)
                    .fill(Color.clear)
                    .frame(width: triggerWidth, height: 18)
                    .offset(y: -12)
                    .contentShape(Capsule(style: .continuous))
                    .onHover(perform: handleTriggerHover)

                if model.isExpanded {
                    expandedTray
                        .transition(.asymmetric(insertion: .offset(y: -10).combined(with: .opacity), removal: .opacity))
                }
            }
        }
        .frame(width: panelWidth, height: panelHeight, alignment: .top)
        .onAppear {
            notchMetrics = NotchMetrics.current()
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.92), value: model.isExpanded)
    }

    private var expandedTray: some View {
        VStack(spacing: 16) {
            heroPanel
            sectionPicker
            detailPanel
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.06, green: 0.07, blue: 0.11), Color(red: 0.04, green: 0.05, blue: 0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black)
                .frame(width: triggerWidth + 10, height: 24)
                .offset(y: -11)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 28, y: 12)
        .frame(width: 740, alignment: .top)
        .offset(y: -22)
        .onHover { hovering in
            isPointerInTray = hovering
            if hovering {
                hoverCloseTask?.cancel()
            } else {
                scheduleCollapseIfNeeded()
            }
        }
    }

    private var heroPanel: some View {
        HStack(alignment: .center, spacing: 18) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.95), Color.blue.opacity(0.8), Color.mint.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Image(systemName: model.activeSection.symbolName)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 8) {
                Text(model.heroTitle)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(model.heroSummary)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(2)

                HStack(spacing: 10) {
                    statPill("Avg reply", value: model.avgReplyTime)
                    statPill("Next action", value: model.nextRecommendedAction)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                statusPill(title: model.autoReplyEnabled ? "Auto-replies live" : "Manual mode", tint: model.autoReplyEnabled ? .green : .orange)
                Button(action: { model.isExpanded = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.74))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var sectionPicker: some View {
        HStack(spacing: 10) {
            ForEach(ReceptionSection.allCases) { section in
                Button(action: { model.activeSection = section }) {
                    HStack(spacing: 8) {
                        Image(systemName: section.symbolName)
                            .font(.system(size: 13, weight: .semibold))
                        Text(section.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(model.activeSection == section ? .black : .white.opacity(0.78))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(model.activeSection == section ? Color.white : Color.white.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var detailPanel: some View {
        switch model.activeSection {
        case .overview:
            overviewPanel
        case .inbox:
            inboxPanel
        case .schedule:
            schedulePanel
        case .automations:
            automationsPanel
        }
    }

    private var overviewPanel: some View {
        HStack(spacing: 16) {
            card {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Revenue Snapshot")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(model.pipelineMetrics) { metric in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(metric.label)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.52))
                                Text(metric.value)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(metric.delta)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(metric.tint)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                    Spacer()
                }
            }

            card {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Recent Activity")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    ForEach(model.activityFeed.prefix(4)) { item in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 34, height: 34)
                                .overlay {
                                    Image(systemName: item.symbol)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(item.timestamp, style: .relative)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.48))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        chipButton("Open Inbox", systemImage: "message.fill", action: model.focusInbox)
                        chipButton("Check Schedule", systemImage: "calendar", action: model.focusSchedule)
                    }
                }
            }
        }
    }

    private var inboxPanel: some View {
        HStack(spacing: 16) {
            card {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Priority Leads")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    ForEach(model.conversations) { lead in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(lead.customerName)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("\(lead.channel) • \(lead.requestedService)")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.48))
                                }
                                Spacer()
                                statusPill(title: lead.priority, tint: lead.accent)
                            }

                            Text(lead.summary)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.72))

                            Text("“\(lead.lastMessagePreview)”")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(2)

                            HStack {
                                Text(lead.etaText)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.56))
                                Spacer()
                                if lead.readyToBook {
                                    Text("Ready to book")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    Spacer()
                }
            }

            card {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Action Console")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Use this as the core paid promise: every missed inquiry gets an immediate, on-brand response and a path to booking.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))

                    Divider().overlay(Color.white.opacity(0.08))

                    quickFact(label: "Response promise", value: "Under 60 seconds")
                    quickFact(label: "Live channels", value: "Calls, SMS, web chat")
                    quickFact(label: "Qualification", value: "Intent, urgency, insurance")

                    Spacer()

                    HStack(spacing: 10) {
                        chipButton("Send Reply", systemImage: "paperplane.fill", action: model.triggerInstantReply)
                        chipButton("Book Lead", systemImage: "calendar.badge.plus", action: model.bookTopLead)
                    }
                }
            }
        }
    }

    private var schedulePanel: some View {
        HStack(spacing: 16) {
            card {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Appointments")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    ForEach(model.appointments) { appointment in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(appointment.time)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(appointment.assignee)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.46))
                            }
                            .frame(width: 86, alignment: .leading)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(appointment.customerName)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(appointment.service)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.56))
                            }

                            Spacer()
                            statusPill(title: appointment.status, tint: appointment.status == "Booked" ? .green : .blue)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    Spacer()
                }
            }

            card {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Why customers pay")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    featureRow(symbol: "phone.badge.checkmark", text: "Turn missed calls into same-day appointments.")
                    featureRow(symbol: "bell.badge.fill", text: "Automate reminders before humans forget.")
                    featureRow(symbol: "list.clipboard.fill", text: "Collect intake details before the front desk picks up.")

                    Spacer()

                    chipButton("View Flows", systemImage: "bolt.badge.automatic.fill", action: model.focusAutomations)
                }
            }
        }
    }

    private var automationsPanel: some View {
        HStack(spacing: 16) {
            card {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Automation Library")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    ForEach(model.workflows) { workflow in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(workflow.name)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                statusPill(title: workflow.status, tint: workflow.status == "Healthy" ? .green : .orange)
                            }

                            Text(workflow.description)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.62))

                            Text(workflow.liveCount)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.48))
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    Spacer()
                }
            }

            card {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Operator Controls")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Keep the demo honest: the value is reliable follow-up and booking recovery, not pressure tactics.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))

                    Divider().overlay(Color.white.opacity(0.08))

                    quickFact(label: "Business fit", value: "Dental, med spa, legal, home services")
                    quickFact(label: "Core pricing", value: "$299 to $999 per location")
                    quickFact(label: "Expansion", value: "More locations, CRM sync, voice")

                    Spacer()

                    HStack(spacing: 10) {
                        chipButton(model.autoReplyEnabled ? "Pause Auto-replies" : "Resume Auto-replies", systemImage: model.autoReplyEnabled ? "pause.fill" : "play.fill", action: model.toggleAutoReply)
                    }
                }
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0, content: content)
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 248, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func quickFact(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 4)
    }

    private func featureRow(symbol: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
        }
    }

    private func chipButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func statPill(_ title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06), in: Capsule())
    }

    private func statusPill(title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.28), in: Capsule())
            .overlay {
                Capsule().strokeBorder(tint.opacity(0.38), lineWidth: 1)
            }
    }

    private func handleTriggerHover(_ hovering: Bool) {
        isPointerInTrigger = hovering
        if hovering {
            hoverCloseTask?.cancel()
            model.prepareForReveal(force: true)
            if model.hoverExpansionEnabled {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                    model.isExpanded = true
                }
            }
        } else {
            scheduleCollapseIfNeeded()
        }
    }

    private func scheduleCollapseIfNeeded() {
        guard model.hoverExpansionEnabled else { return }
        hoverCloseTask?.cancel()
        let delay = model.autoCollapseDelay
        hoverCloseTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if !isPointerInTrigger && !isPointerInTray {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.92)) {
                        model.isExpanded = false
                    }
                }
            }
        }
    }
}

private struct NotchMetrics {
    let hardwareWidth: CGFloat

    static func current() -> NotchMetrics {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return NotchMetrics(hardwareWidth: 126)
        }

        let left = screen.auxiliaryTopLeftArea ?? .zero
        let right = screen.auxiliaryTopRightArea ?? .zero
        let hasNotch = !left.isEmpty && !right.isEmpty && right.minX > left.maxX
        guard hasNotch else {
            return NotchMetrics(hardwareWidth: 126)
        }

        return NotchMetrics(hardwareWidth: max(120, right.minX - left.maxX))
    }
}

struct MenuBarControlsView: View {
    @ObservedObject var model: UnoNotchModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Front Desk AI")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Text("A compact receptionist dashboard for recovering missed leads and booking them automatically.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            HStack {
                Button("Reveal") {
                    model.prepareForReveal(force: true)
                    model.isExpanded = true
                }
                Button("Inbox") {
                    model.focusInbox()
                    model.isExpanded = true
                }
            }

            Divider()

            HStack {
                Button(model.autoReplyEnabled ? "Pause Replies" : "Resume Replies") {
                    model.toggleAutoReply()
                }
                Button("Book Top Lead") {
                    model.bookTopLead()
                }
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}

struct SettingsView: View {
    @ObservedObject var model: UnoNotchModel

    var body: some View {
        Form {
            Section("Experience") {
                Toggle("Invisible until hover", isOn: $model.hideUntilHover)
                Toggle("Expand on hover", isOn: $model.hoverExpansionEnabled)
                HStack {
                    Text("Auto collapse")
                    Spacer()
                    Text("\(model.autoCollapseDelay, specifier: "%.2f")s")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $model.autoCollapseDelay, in: 0.2...1.2, step: 0.05)
            }

            Section("Reception") {
                TextField("Business name", text: $model.businessName)
                Toggle("Instant auto-replies", isOn: $model.autoReplyEnabled)
                Toggle("Sound effects", isOn: $model.soundEffectsEnabled)
            }

            Section("Positioning") {
                TextField("Welcome line", text: $model.welcomeLine)
                Text("The demo is tuned for service businesses that lose revenue from missed calls and slow text follow-up.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
