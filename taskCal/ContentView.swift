import SwiftUI
import EventKit
import UniformTypeIdentifiers
import Combine

struct ContentView: View {
	@StateObject private var viewModel = TaskViewModel()
	@State private var selectedDayOffset = 0
	// Retain Dark/Light mode toggle state
	@AppStorage("isDarkMode") private var isDarkMode = false
	@State private var markedEventIDs: Set<String> = []
	
	var body: some View {
		ZStack {
			VStack(alignment: .leading, spacing: 0) {
				// Header with navigation
				HStack {
					Button(action: {
						selectedDayOffset -= 1
					}) {
						Image(systemName: "chevron.left")
							.font(.system(size: 20))
					}
					.buttonStyle(.plain)
					
					Spacer()
					
					Text(headerTitle)
						.font(.system(size: 32, weight: .bold))
						.onTapGesture(count: 2) {
							selectedDayOffset = 0
						}
					
					Spacer()
					
					Button(action: {
						selectedDayOffset += 1
					}) {
						Image(systemName: "chevron.right")
							.font(.system(size: 20))
					}
					.buttonStyle(.plain)
					
					Button(action: {
						viewModel.refresh()
					}) {
						Image(systemName: "arrow.clockwise")
							.font(.system(size: 16))
					}
					.buttonStyle(.plain)
					.padding(.leading, 16)
				}
				.padding(.horizontal, 24)
				.padding(.vertical, 20)
				
				Divider()
				
				// Task list
				if viewModel.isLoading {
					VStack {
						Spacer()
						ProgressView()
						Text("Loading...")
							.foregroundColor(.secondary)
							.padding(.top)
						Spacer()
					}
					.frame(maxWidth: .infinity)
				} else if viewModel.needsPermission {
					VStack(spacing: 20) {
						Spacer()
						Image(systemName: "lock.shield")
							.font(.system(size: 60))
							.foregroundColor(.secondary)
						Text("Permission Required")
							.font(.title2)
							.fontWeight(.semibold)
						Text("This app needs access to your Calendar and Reminders")
							.foregroundColor(.secondary)
						Button("Grant Access") {
							viewModel.requestPermissions()
						}
						.buttonStyle(.borderedProminent)
						Spacer()
					}
					.frame(maxWidth: .infinity)
				} else {
					ScrollView {
						LazyVStack(alignment: .leading, spacing: 0) {
							let items = viewModel.itemsForDay(offset: selectedDayOffset)
							
							if items.isEmpty {
								VStack {
									Spacer()
									Text("No tasks or events")
										.foregroundColor(.secondary)
										.font(.title3)
									Spacer()
								}
								.frame(maxWidth: .infinity)
								.frame(height: 300)
							} else {
								ForEach(items) { item in
									VStack(spacing: 0) {
										TaskItemView(
											item: item,
											viewModel: viewModel,
											isEventMarkedComplete: markedEventIDs.contains(item.stableID),
											onToggleEventCompletion: {
												if markedEventIDs.contains(item.stableID) {
													markedEventIDs.remove(item.stableID)
												} else {
													markedEventIDs.insert(item.stableID)
												}
												saveMarkedEvents()
											}
										)
										
										if item.id != items.last?.id {
											Divider()
												.padding(.leading, 52)
										}
									}
								}
							}
						}
						.padding(.horizontal, 24)
						.padding(.top, 16)
					}
				}
			}
			.onAppear {
				viewModel.requestPermissions()
				loadMarkedEvents()
			}
			
			// Dark mode toggle in bottom right
			VStack {
				Spacer()
				HStack {
					Spacer()
					Button(action: {
						isDarkMode.toggle()
					}) {
						Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
							.font(.system(size: 20))
							.foregroundColor(.primary)
					}
					.buttonStyle(.plain)
					.padding(24)
				}
			}
		}
		.preferredColorScheme(isDarkMode ? .dark : .light)
	}
	
	private var headerTitle: String {
		let calendar = Calendar.current
		let date = calendar.date(byAdding: .day, value: selectedDayOffset, to: Date())!
		let formatter = DateFormatter()
		
		if selectedDayOffset == 0 {
			return "Today"
		} else if selectedDayOffset == 1 {
			return "Tomorrow"
		} else if selectedDayOffset == -1 {
			return "Yesterday"
		} else {
			formatter.dateFormat = "EEEE, MMM d"
			return formatter.string(from: date)
		}
	}
	
	private func saveMarkedEvents() {
		let array = Array(markedEventIDs)
		UserDefaults.standard.set(array, forKey: "markedEventIDs")
	}
	
	private func loadMarkedEvents() {
		if let array = UserDefaults.standard.array(forKey: "markedEventIDs") as? [String] {
			markedEventIDs = Set(array)
		}
	}
}

struct TaskItemView: View {
	let item: TaskItem
	let viewModel: TaskViewModel
	let isEventMarkedComplete: Bool
	let onToggleEventCompletion: () -> Void
	
	@State private var isAnimating = false
	
	private var displayAsCompleted: Bool {
		item.isCompleted || (item.type == .event && isEventMarkedComplete)
	}
	
	var body: some View {
		HStack(alignment: .center, spacing: 16) {
			// Icon based on type
			if item.type == .reminder {
				ZStack {
					RoundedRectangle(cornerRadius: 6)
						.strokeBorder(displayAsCompleted ? Color.green : Color.secondary.opacity(0.3), lineWidth: 2)
						.background(displayAsCompleted ? Color.green.opacity(0.1) : Color.clear)
						.frame(width: 20, height: 20)
					
					if displayAsCompleted {
						Image(systemName: "checkmark")
							.font(.system(size: 12, weight: .bold))
							.foregroundColor(.green)
							.scaleEffect(isAnimating ? 1.0 : 0.5)
							.opacity(isAnimating ? 1.0 : 0.0)
					}
				}
				.frame(width: 20, height: 20)
				.scaleEffect(isAnimating ? 1.1 : 1.0)
				.contentShape(Rectangle())
				.onTapGesture {
					print("Tapped on reminder: \(item.title)")
					
					// Animate the checkbox
					withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
						isAnimating = true
					}
					
					// Toggle completion
					viewModel.toggleCompletion(for: item)
					
					// Reset animation state
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
						isAnimating = false
					}
				}
			} else {
				ZStack {
					Image(systemName: "calendar")
						.font(.system(size: 16))
						.foregroundColor(item.isAllDay ? .orange : .red)
						.frame(width: 20, height: 20)
					
					if isEventMarkedComplete {
						Image(systemName: "checkmark.circle.fill")
							.font(.system(size: 10))
							.foregroundColor(.green)
							.offset(x: 8, y: -8)
					}
				}
				.frame(width: 20, height: 20)
			}
			
			// Task content
			VStack(alignment: .leading, spacing: 2) {
				Text(item.title)
					.font(.system(size: 17))
					.strikethrough(displayAsCompleted)
					.foregroundColor(displayAsCompleted ? .secondary : .primary)
				
				if let time = item.timeString {
					Text(time)
						.font(.system(size: 13))
						.foregroundColor(.secondary)
				}
			}
			
			Spacer()
		}
		.padding(.vertical, 12)
		.padding(.horizontal, 16)
		.background(Color(NSColor.controlBackgroundColor))
		.opacity(displayAsCompleted ? 0.6 : 1.0)
		.onTapGesture(count: 2) {
			openInNativeApp()
		}
		.contextMenu {
			if item.type == .event {
				Button(isEventMarkedComplete ? "Mark as Incomplete" : "Mark as Complete") {
					onToggleEventCompletion()
				}
			}
		}
	}
	
	private func openInNativeApp() {
		if item.type == .reminder {
			// Open in Reminders app
			if let reminder = item.originalObject as? EKReminder {
				let urlString = "x-apple-reminderkit://REMCDReminder/\(reminder.calendarItemIdentifier)"
				if let url = URL(string: urlString) {
					NSWorkspace.shared.open(url)
				}
			}
		} else {
			// Open in Calendar app
			if let event = item.originalObject as? EKEvent,
			   let eventID = event.eventIdentifier {
				// Calendar uses a different URL scheme
				let urlString = "ical://ekevent/\(eventID)"
				if let url = URL(string: urlString) {
					NSWorkspace.shared.open(url)
				}
			}
		}
	}
}

// MARK: - Models

enum ItemType {
	case reminder
	case event
}

struct TaskItem: Identifiable {
	let id = UUID()
	let title: String
	let date: Date?
	let isCompleted: Bool
	let type: ItemType
	let listName: String?
	let isAllDay: Bool
	let hasTime: Bool
	let originalObject: Any // EKReminder or EKEvent
	let stableID: String // Stable identifier for persistence
	
	var timeString: String? {
		if type == .event {
			if isAllDay {
				return "All Day Event"
			}
			guard let date = date else { return nil }
			let formatter = DateFormatter()
			formatter.dateFormat = "HH:mm"
			return formatter.string(from: date)
		} else {
			// For reminders
			if !hasTime {
				return "Anytime task"
			}
			guard let date = date else { return nil }
			let formatter = DateFormatter()
			formatter.dateFormat = "HH:mm"
			return formatter.string(from: date)
		}
	}
}

// MARK: - ViewModel

@MainActor
class TaskViewModel: ObservableObject {
	@Published var items: [TaskItem] = []
	@Published var isLoading = false
	@Published var needsPermission = true
	@Published var draggedItem: TaskItem?
	
	private let eventStore = EKEventStore()
	
	func requestPermissions() {
		isLoading = true
		
		let group = DispatchGroup()
		var reminderGranted = false
		var calendarGranted = false
		
		group.enter()
		if #available(macOS 14.0, *) {
			eventStore.requestFullAccessToReminders { granted, _ in
				reminderGranted = granted
				group.leave()
			}
		} else {
			eventStore.requestAccess(to: .reminder) { granted, _ in
				reminderGranted = granted
				group.leave()
			}
		}
		
		group.enter()
		if #available(macOS 14.0, *) {
			eventStore.requestFullAccessToEvents { granted, _ in
				calendarGranted = granted
				group.leave()
			}
		} else {
			eventStore.requestAccess(to: .event) { granted, _ in
				calendarGranted = granted
				group.leave()
			}
		}
		
		group.notify(queue: .main) {
			self.needsPermission = !reminderGranted || !calendarGranted
			self.isLoading = false
			
			if !self.needsPermission {
				self.loadData()
			}
		}
	}
	
	func refresh() {
		loadData()
	}
	
	func loadData() {
		isLoading = true
		
		let group = DispatchGroup()
		var allItems: [TaskItem] = []
		
		// Load reminders
		group.enter()
		let predicate = eventStore.predicateForReminders(in: nil)
		eventStore.fetchReminders(matching: predicate) { reminders in
			if let reminders = reminders {
				let reminderItems = reminders.compactMap { reminder -> TaskItem? in
					guard let dueDate = reminder.dueDateComponents?.date else { return nil }
					
					// Only show reminders within the date range we care about
					let calendar = Calendar.current
					let startDate = calendar.date(byAdding: .day, value: -7, to: Date())!
					let endDate = calendar.date(byAdding: .day, value: 14, to: Date())!
					
					guard dueDate >= startDate && dueDate < endDate else { return nil }
					
					// Check if reminder has a time set (hour and minute components)
					let hasTime = reminder.dueDateComponents?.hour != nil &&
					reminder.dueDateComponents?.minute != nil
					
					return TaskItem(
						title: reminder.title ?? "Untitled",
						date: dueDate,
						isCompleted: reminder.isCompleted,
						type: .reminder,
						listName: reminder.calendar.title,
						isAllDay: false,
						hasTime: hasTime,
						originalObject: reminder,
						stableID: reminder.calendarItemIdentifier
					)
				}
				allItems.append(contentsOf: reminderItems)
			}
			group.leave()
		}
		
		// Load calendar events
		group.enter()
		Task {
			let calendar = Calendar.current
			let startDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -7, to: Date())!)
			let endDate = calendar.date(byAdding: .day, value: 14, to: startDate)!
			
			let eventPredicate = self.eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
			let events = self.eventStore.events(matching: eventPredicate)
			
			let eventItems = events.map { event in
				TaskItem(
					title: event.title ?? "Untitled Event",
					date: event.startDate,
					isCompleted: false,
					type: .event,
					listName: event.calendar.title,
					isAllDay: event.isAllDay,
					hasTime: !event.isAllDay,
					originalObject: event,
					stableID: event.eventIdentifier ?? UUID().uuidString
				)
			}
			
			await MainActor.run {
				allItems.append(contentsOf: eventItems)
				group.leave()
			}
		}
		
		group.notify(queue: .main) {
			self.items = allItems.sorted { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }
			self.isLoading = false
		}
	}
	
	func itemsForDay(offset: Int) -> [TaskItem] {
		let calendar = Calendar.current
		let targetDate = calendar.date(byAdding: .day, value: offset, to: Date())!
		let startOfDay = calendar.startOfDay(for: targetDate)
		let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
		
		return items.filter { item in
			guard let date = item.date else { return false }
			return date >= startOfDay && date < endOfDay
		}
	}
	
	func toggleCompletion(for item: TaskItem) {
		print("Toggle completion called for: \(item.title)")
		
		guard item.type == .reminder,
			  let reminder = item.originalObject as? EKReminder else {
			print("Not a reminder or couldn't cast to EKReminder")
			return
		}
		
		print("Current completion state: \(reminder.isCompleted)")
		reminder.isCompleted = !reminder.isCompleted
		print("New completion state: \(reminder.isCompleted)")
		
		do {
			try eventStore.save(reminder, commit: true)
			print("Successfully saved reminder")
			// Immediately update the UI by reloading data
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
				self.loadData()
			}
		} catch {
			print("Error updating reminder: \(error.localizedDescription)")
			// Revert the change in UI if save failed
			reminder.isCompleted = !reminder.isCompleted
		}
	}
}
