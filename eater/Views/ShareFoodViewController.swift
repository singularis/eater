import SwiftUI
import UIKit

final class ShareFoodViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  private let foodName: String
  private let time: Int64
  private var tableView: UITableView!
  private var emails: [String] = []
  private var totalCount: Int = 0
  private var isLoading: Bool = false
  private var sharesCountByEmail: [String: Int] = ShareFoodViewController.loadSharesCount()
  var onShareSuccess: (() -> Void)?

  init(foodName: String, time: Int64) {
    self.foodName = foodName
    self.time = time
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    title = String(format: loc("share.title", "Share %@"), foodName)
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .close, target: self, action: #selector(closeTapped))
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: loc("friends.add", "Add Friend"), style: .plain, target: self,
      action: #selector(addFriendTapped))

    tableView = UITableView(frame: .zero, style: .insetGrouped)
    tableView.translatesAutoresizingMaskIntoConstraints = false
    tableView.delegate = self
    tableView.dataSource = self
    view.addSubview(tableView)
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    fetchFriends(reset: true)
  }

  @objc private func closeTapped() { dismiss(animated: true) }

  @objc private func addFriendTapped() {
    // Bridge a Binding<Bool> so when SwiftUI sets isPresented=false, we dismiss the hosting controller
    let presentedBinding = Binding<Bool>(
      get: { true },
      set: { [weak self] newValue in
        if newValue == false {
          self?.dismiss(animated: true)
        }
      }
    )

    let root = AddFriendsView(isPresented: presentedBinding)
    let host = UIHostingController(rootView: root)
    present(host, animated: true)
  }

  private func fetchFriends(reset: Bool) {
    guard !isLoading else { return }
    isLoading = true
    let offset = reset ? 0 : emails.count
    let limit = 5
    GRPCService().getFriends(offset: offset, limit: limit) { [weak self] emails, total in
      DispatchQueue.main.async {
        guard let self = self else { return }
        self.isLoading = false
        if reset { self.emails.removeAll() }
        self.totalCount = total
        self.emails.append(contentsOf: emails)
        self.sortEmails()
        self.tableView.reloadData()
        self.addLoadMoreIfNeeded()
      }
    }
  }

  private func sortEmails() {
    emails.sort { a, b in
      let sa = sharesCountByEmail[a] ?? 0
      let sb = sharesCountByEmail[b] ?? 0
      if sa == sb { return a.localizedCaseInsensitiveCompare(b) == .orderedAscending }
      return sa > sb
    }
  }

  private func addLoadMoreIfNeeded() {
    if emails.count < totalCount {
      let footer = UIButton(type: .system)
      var config = UIButton.Configuration.filled()
      config.title = loc("friends.more", "More friends")
      config.baseBackgroundColor = .clear
      config.baseForegroundColor = view.tintColor
      config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0)
      footer.configuration = config
      footer.addTarget(self, action: #selector(loadMoreTapped), for: .touchUpInside)
      footer.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
      let container = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 56))
      footer.frame = container.bounds
      container.addSubview(footer)
      tableView.tableFooterView = container
    } else {
      tableView.tableFooterView = nil
    }
  }

  @objc private func loadMoreTapped() {
    fetchFriends(reset: false)
  }

  // MARK: - UITableView DataSource

  func numberOfSections(in _: UITableView) -> Int { 1 }
  func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int { emails.count }
  func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
    let email = emails[indexPath.row]
    let shares = sharesCountByEmail[email] ?? 0
    cell.textLabel?.text = email
    cell.detailTextLabel?.text = shares > 0 ? "Shared \(shares)x" : ""
    cell.accessoryType = .disclosureIndicator
    return cell
  }

  // MARK: - UITableView Delegate

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let toEmail = emails[indexPath.row]
    guard let fromEmail = UserDefaults.standard.string(forKey: "user_email") else { return }
    promptSharePercentage { [weak self] percentage in
      guard let self = self else { return }
      GRPCService().shareFood(
        time: self.time, fromEmail: fromEmail, toEmail: toEmail, percentage: percentage
      ) { [weak self] success in
        DispatchQueue.main.async {
          guard let self = self else { return }
          if success {
            Self.incrementShareCount(email: toEmail)
            self.sharesCountByEmail = Self.loadSharesCount()
            self.sortEmails()
            self.tableView.reloadData()
            let message = "Shared \(percentage)% with \(toEmail)"
            let callback = self.onShareSuccess
            self.dismiss(animated: true) {
              callback?()
              AlertHelper.showAlert(title: "Shared", message: message)
            }
          } else {
            AlertHelper.showAlert(title: "Failed", message: "Could not share with \(toEmail)")
          }
        }
      }
    }
  }

  private func promptSharePercentage(onSelected: @escaping (Int32) -> Void) {
    let alert = UIAlertController(
      title: "How much did your friend eat?", message: nil, preferredStyle: .actionSheet)
    let options: [Int32] = [25, 50, 75]
    for v in options {
      alert.addAction(
        UIAlertAction(title: "\(v)%", style: .default, handler: { _ in onSelected(v) }))
    }
    alert.addAction(
      UIAlertAction(
        title: "Custom...", style: .default,
        handler: { [weak self] _ in
          self?.promptCustomPercentage(onSelected: onSelected)
        }))
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    present(alert, animated: true)
  }

  private func promptCustomPercentage(onSelected: @escaping (Int32) -> Void) {
    let alert = UIAlertController(
      title: "Custom percentage", message: "Enter a value between 1 and 300", preferredStyle: .alert
    )
    alert.addTextField { tf in
      tf.placeholder = "e.g. 40"
      tf.keyboardType = .numberPad
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(
      UIAlertAction(
        title: "OK", style: .default,
        handler: { _ in
          if let text = alert.textFields?.first?.text, let value = Int(text), value > 0,
            value <= 300
          {
            onSelected(Int32(value))
          }
        }))
    present(alert, animated: true)
  }

  // MARK: - Persistence of share counts

  private static let sharesKey = "friend_shares_counts"
  private static func loadSharesCount() -> [String: Int] {
    if let data = UserDefaults.standard.data(forKey: sharesKey),
      let dict = try? JSONDecoder().decode([String: Int].self, from: data)
    {
      return dict
    }
    return [:]
  }

  private static func incrementShareCount(email: String) {
    var dict = loadSharesCount()
    dict[email, default: 0] += 1
    if let data = try? JSONEncoder().encode(dict) {
      UserDefaults.standard.set(data, forKey: sharesKey)
    }
  }
}
