import SwiftUI
import UIKit

final class ShareFoodViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  private let foodName: String
  private let time: Int64
  private let imageId: String
  private var tableView: UITableView!
  private var headerImageView: UIImageView?
  private var friends: [(email: String, nickname: String)] = []
  private var totalCount: Int = 0
  private var isLoading: Bool = false
  private var sharesCountByEmail: [String: Int] = ShareFoodViewController.loadSharesCount()
  var onShareSuccess: (() -> Void)?

  init(foodName: String, time: Int64, imageId: String = "") {
    self.foodName = foodName
    self.time = time
    self.imageId = imageId
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

    setupTableView()
    setupHeader()
    fetchFriends(reset: true)
    loadImage()
  }

  private func setupTableView() {
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
  }

  private func setupHeader() {
    let container = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 160))
    let imageView = UIImageView()
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.contentMode = .scaleAspectFill
    imageView.clipsToBounds = true
    imageView.layer.cornerRadius = 16
    imageView.backgroundColor = .secondarySystemBackground
    imageView.image = UIImage(systemName: "photo") // Placeholder
    imageView.tintColor = .systemGray4
    
    container.addSubview(imageView)
    headerImageView = imageView
    
    NSLayoutConstraint.activate([
      imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
      imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      imageView.widthAnchor.constraint(equalToConstant: 120),
      imageView.heightAnchor.constraint(equalToConstant: 120)
    ])
    
    tableView.tableHeaderView = container
  }

  private func loadImage() {
    // 1. Try local image by time
    if let localImage = ImageStorageService.shared.loadImage(forTime: time) {
      headerImageView?.image = localImage
      return
    }

    // 2. Try cached remote image
    if !imageId.isEmpty, let cached = ImageStorageService.shared.loadCachedImage(forImageId: imageId) {
      headerImageView?.image = cached
      return
    }
    
    // 3. Fetch from network if needed
    if !imageId.isEmpty {
      headerImageView?.image = nil // Show loading state on placeholder or activity indicator could be added
      
      // Add spinner
      let spinner = UIActivityIndicatorView(style: .medium)
      spinner.translatesAutoresizingMaskIntoConstraints = false
      spinner.startAnimating()
      if let header = tableView.tableHeaderView {
         header.addSubview(spinner)
         NSLayoutConstraint.activate([
             spinner.centerXAnchor.constraint(equalTo: header.centerXAnchor),
             spinner.centerYAnchor.constraint(equalTo: header.centerYAnchor)
         ])
      }

      FoodPhotoService.shared.fetchPhoto(imageId: imageId) { [weak self] image in
        DispatchQueue.main.async {
          spinner.removeFromSuperview()
          if let image = image {
            self?.headerImageView?.image = image
          } else {
             self?.headerImageView?.image = UIImage(systemName: "photo")
          }
        }
      }
    }
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
    let offset = reset ? 0 : friends.count
    let limit = 5
    GRPCService().getFriends(offset: offset, limit: limit) { [weak self] fetchedFriends, total in
      DispatchQueue.main.async {
        guard let self = self else { return }
        self.isLoading = false
        if reset { self.friends.removeAll() }
        self.totalCount = total
        self.friends.append(contentsOf: fetchedFriends)
        self.sortFriends()
        self.tableView.reloadData()
        self.addLoadMoreIfNeeded()
      }
    }
  }

  private func sortFriends() {
    friends.sort { a, b in
      let sa = sharesCountByEmail[a.email] ?? 0
      let sb = sharesCountByEmail[b.email] ?? 0
      if sa == sb {
           let nameA = a.nickname.isEmpty ? a.email : a.nickname
           let nameB = b.nickname.isEmpty ? b.email : b.nickname
           return nameA.localizedCaseInsensitiveCompare(nameB) == .orderedAscending
      }
      return sa > sb
    }
  }

  private func addLoadMoreIfNeeded() {
    if friends.count < totalCount {
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
  func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int { friends.count }
  func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
    let friend = friends[indexPath.row]
    let shares = sharesCountByEmail[friend.email] ?? 0
    
    let displayName = friend.nickname.isEmpty ? friend.email : friend.nickname
    
    cell.textLabel?.text = displayName
    
    var details = [String]()
    if shares > 0 { details.append("Shared \(shares)x") }
    if !friend.nickname.isEmpty { details.append(friend.email) }
    
    cell.detailTextLabel?.text = details.joined(separator: " • ")
    cell.accessoryType = .disclosureIndicator
    return cell
  }

  private lazy var sharingSpinner: UIActivityIndicatorView = {
    let spinner = UIActivityIndicatorView(style: .large)
    spinner.translatesAutoresizingMaskIntoConstraints = false
    spinner.hidesWhenStopped = true
    spinner.color = .label
    return spinner
  }()

  // MARK: - UITableView Delegate

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let friend = friends[indexPath.row]
    let toEmail = friend.email
    guard let fromEmail = UserDefaults.standard.string(forKey: "user_email") else { return }
    
    promptSharePercentage { [weak self] percentage in
      guard let self = self else { return }
      
      self.showSharingLoading()
      
      GRPCService().shareFood(
        time: self.time, fromEmail: fromEmail, toEmail: toEmail, percentage: percentage
      ) { [weak self] success, nickname in
        DispatchQueue.main.async {
          guard let self = self else { return }
          self.hideSharingLoading()
          
          if success {
            Self.incrementShareCount(email: toEmail)
            self.sharesCountByEmail = Self.loadSharesCount()
            self.sortFriends()
            self.tableView.reloadData()
            let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let nameUsed = (trimmed?.isEmpty ?? true) ? toEmail : trimmed!
            let message = "Shared \(percentage)% with \(nameUsed)"
            
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

  private func showSharingLoading() {
    if sharingSpinner.superview == nil {
      view.addSubview(sharingSpinner)
      NSLayoutConstraint.activate([
        sharingSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        sharingSpinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
      ])
    }
    view.isUserInteractionEnabled = false
    sharingSpinner.startAnimating()
  }

  private func hideSharingLoading() {
    view.isUserInteractionEnabled = true
    sharingSpinner.stopAnimating()
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
