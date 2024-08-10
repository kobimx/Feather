//
//  SearchResultsTableViewController.swift
//  feather
//
//  Created by samara on 8/8/24.
//

import Foundation
import UIKit

class SearchResultsTableViewController: UIViewController, UISearchResultsUpdating, UITableViewDataSource, UITableViewDelegate {
	var tableView: UITableView!
	var sources: [Source] = []
	var fetchedSources: [URL: SourcesData] = [:]
	var filteredSources: [SourcesData: [StoreAppsData]] = [:]
	var sourceURLMapping: [SourcesData: URL] = [:]

	override func viewDidLoad() {
		super.viewDidLoad()
		self.tableView = UITableView(frame: .zero, style: .insetGrouped)
		self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
		self.view.addSubview(tableView)
		self.tableView.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			tableView.topAnchor.constraint(equalTo: view.topAnchor),
			tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
		])
		
		self.tableView.dataSource = self
		self.tableView.delegate = self
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		fetchAppsForSources()
	}
	
	func numberOfSections(in tableView: UITableView) -> Int { return filteredSources.keys.count }
	func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { return 40 }
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		let source = Array(filteredSources.keys)[section]
		return filteredSources[source]?.count ?? 0
	}
	
	func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		let source = Array(filteredSources.keys)[section]
		let header = SearchAppSectionHeader(title: source.name ?? "Unknown", icon: UIImage(named: "unknown"))
		let iconURL = source.iconURL ?? source.apps.first?.iconURL
		loadAndSetImage(from: iconURL, for: header)
		return header
	}

	private func loadAndSetImage(from url: URL?, for header: SearchAppSectionHeader) {
		guard let url = url else {
			header.setIcon(with: UIImage(named: "unknown"))
			return
		}
		SectionIcons.loadImageFromURL(from: url) { image in
			header.setIcon(with: image ?? UIImage(named: "unknown"))
		}
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
		
		let source = Array(filteredSources.keys)[indexPath.section]
		let app = filteredSources[source]?[indexPath.row]
		
		var appname = app?.name ?? "Unknown"
		
		if app!.bundleIdentifier.hasSuffix("Beta") {
			appname += " (Beta)"
		}
		
		cell.textLabel?.text = appname
		cell.detailTextLabel?.text = app?.versions?[0].version ?? app?.version
		cell.detailTextLabel?.textColor = .secondaryLabel

		cell.accessoryType = .disclosureIndicator
		
		let placeholderImage = UIImage(named: "unknown")
		let imageSize = CGSize(width: 30, height: 30)
		
		func setImage(_ image: UIImage?) {
			let resizedImage = UIGraphicsImageRenderer(size: imageSize).image { context in
				image?.draw(in: CGRect(origin: .zero, size: imageSize))
			}
			cell.imageView?.image = resizedImage
			cell.imageView?.layer.cornerRadius = 7
			cell.imageView?.layer.cornerCurve = .continuous
			cell.imageView?.layer.borderWidth = 1
			cell.imageView?.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.3).cgColor
			cell.imageView?.clipsToBounds = true
		}

		setImage(placeholderImage)
		
		if let iconURL = app?.iconURL {
			SectionIcons.loadImageFromURL(from: iconURL) { image in
				DispatchQueue.main.async {
					if tableView.indexPath(for: cell) == indexPath {
						setImage(image)
					}
				}
			}
		}
		
		return cell
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let source = Array(filteredSources.keys)[indexPath.section]
		let app = filteredSources[source]?[indexPath.row]
		
		if let url = sourceURLMapping[source] {
			let savc = SourceAppViewController()
			savc.name = source.name
			savc.uri = url
			
			savc.highlightAppName = app?.name
			savc.highlightBundleID = app?.bundleIdentifier
			savc.highlightDeveloperName = app?.developerName
			
			let navigationController = UINavigationController(rootViewController: savc)

			if let presentationController = navigationController.presentationController as? UISheetPresentationController {
				presentationController.detents = [.medium(), .large()]
			}
			
			self.present(navigationController, animated: true, completion: nil)
		}
		
		tableView.deselectRow(at: indexPath, animated: true)
	}


	func updateSearchResults(for searchController: UISearchController) {
		let searchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		
		filteredSources.removeAll()
		
		if !searchText.isEmpty {
			for (_, source) in fetchedSources {
				let matchingApps = source.apps.filter { app in
					app.name.localizedCaseInsensitiveContains(searchText)
				}
				if !matchingApps.isEmpty {
					filteredSources[source] = matchingApps
				}
			}
		} else {
			for (_, source) in fetchedSources {
				filteredSources[source] = source.apps
			}
		}
		tableView.reloadData()
	}


	private func fetchAppsForSources() {
		let dispatchGroup = DispatchGroup()
		var allSources: [URL: SourcesData] = [:]
		sourceURLMapping.removeAll()

		for source in sources {
			guard let url = source.sourceURL else { continue }

			dispatchGroup.enter()
			DispatchQueue.global(qos: .background).async {
				SourceGET().downloadURL(from: url) { result in
					switch result {
					case .success((let data, _)):
						switch SourceGET().parse(data: data) {
						case .success(let sourceData):
							allSources[url] = sourceData
							self.sourceURLMapping[sourceData] = url
						case .failure(let error):
							print("Error parsing data: \(error)")
						}
					case .failure(let error):
						print("Error downloading data: \(error)")
					}
					dispatchGroup.leave()
				}
			}
		}

		dispatchGroup.notify(queue: .main) {
			self.fetchedSources = allSources
			self.tableView.reloadData()
		}
	}
}