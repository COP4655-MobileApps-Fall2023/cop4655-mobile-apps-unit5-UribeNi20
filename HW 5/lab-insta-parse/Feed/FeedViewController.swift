//
//  FeedViewController.swift
//  lab-insta-parse
//
//  Created by Charlie Hieger on 11/1/22.
//

import UIKit

// TODO: Import Parse Swift
import ParseSwift


class FeedViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    private var posts = [Post]() {
        didSet {
            // Reload table view data any time the posts variable gets updated.
            tableView.reloadData()
        }
    }
    
    deinit {
            NotificationCenter.default.removeObserver(self, name: Notification.Name("postCreated"), object: nil)
        }
    
    @objc private func postCreated() {
        DispatchQueue.main.async {
            // Dismiss the alert if it is being displayed
            self.presentedViewController?.dismiss(animated: true)
            
            // Hide the placeholder label
            self.placeholderLabel.isHidden = true
            
            // Refresh the feed
            self.queryPosts()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsSelection = false
        
        NotificationCenter.default.addObserver(self, selector: #selector(postCreated), name: Notification.Name("postCreated"), object: nil)
        view.addSubview(placeholderLabel)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            placeholderLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            placeholderLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard let currentUser = User.current else {
            // Show an alert or redirect to login if there is no current user
            return
        }
        
        if currentUser.hasPosted == true {
                placeholderLabel.isHidden = true
                queryPosts()
            } else {
                placeholderLabel.isHidden = false
            }
    }

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = "Post to View Your Feed!"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.textColor = .gray
        label.isHidden = true
        return label
    }()
    

    private func queryPosts() {
        let date = Date().addingTimeInterval(-24*60*60) // 24 hours ago

        let query = Post.query()
            .where("createdAt" > date)
            .order([.descending("createdAt")])
            .limit(10)
            .include("user")

        // Fetch objects (posts) defined in query (async)
        query.find { [weak self] result in
            switch result {
            case .success(let posts):
                // Update local posts property with fetched posts
                self?.posts = posts
                
                // Now, fetch the last post of the logged-in user
                let userLastPostQuery = Post.query()
                    .where("author" == User.current)
                    .order([.descending("createdAt")])
                    .limit(1)

                userLastPostQuery.first { [weak self] result in
                    switch result {
                    case .success(let userLastPost):
                        guard let userLastPostDate = userLastPost.createdAt else { return }
                        // Revised filtering logic
                        let currentPosts = self?.posts ?? [] // Provide a default empty array if self?.posts is nil
                        let filteredPosts = currentPosts.compactMap { post -> Post? in
                            guard let postDate = post.createdAt else { return nil }
                            let timeInterval = postDate.timeIntervalSince(userLastPostDate)
                            return timeInterval <= 24*60*60 ? post : nil
                        }

                        self?.posts = filteredPosts
                        self?.tableView.reloadData()

                    case .failure(let error):
                        // Handle the error, maybe show an alert or log it
                        print("Error fetching user's last post: \(error.localizedDescription)")
                    }
                }

            case .failure(let error):
                self?.showAlert(description: error.localizedDescription)
            }
        }
    }


    @IBAction func onLogOutTapped(_ sender: Any) {
        showConfirmLogoutAlert()
    }
    

    private func showConfirmLogoutAlert() {
        let alertController = UIAlertController(title: "Log out of your account?", message: nil, preferredStyle: .alert)
        let logOutAction = UIAlertAction(title: "Log out", style: .destructive) { _ in
            NotificationCenter.default.post(name: Notification.Name("logout"), object: nil)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alertController.addAction(logOutAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true)
    }

    private func showAlert(description: String? = nil) {
        let alertController = UIAlertController(title: "Oops...", message: "\(description ?? "Please try again...")", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        present(alertController, animated: true)
    }
}

extension FeedViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return placeholderLabel.isHidden ? posts.count : 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "PostCell", for: indexPath) as? PostCell else {
            return UITableViewCell()
        }
        cell.configure(with: posts[indexPath.row])
        return cell
    }
}

extension FeedViewController: UITableViewDelegate { }
