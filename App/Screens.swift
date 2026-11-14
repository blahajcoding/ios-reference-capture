import UIKit

final class HomeVC: UITableViewController {
    let sw = UISwitch()
    let seg = UISegmentedControl(items: ["First", "Second"])
    let slider = UISlider()

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.searchController = UISearchController(searchResultsController: nil)
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: nil, action: nil)
        seg.selectedSegmentIndex = 0
        seg.sizeToFit()
        slider.value = 0.5
        slider.frame = CGRect(x: 0, y: 0, width: 140, height: 34)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "c")
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 4 : 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Controls" : "Danger zone"
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 0 ? "Footer text sits under the group." : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "c", for: ip)
        var cfg = cell.defaultContentConfiguration()
        cell.accessoryView = nil
        cell.accessoryType = .none
        switch (ip.section, ip.row) {
        case (0, 0): cfg.text = "Airplane Mode"; cell.accessoryView = sw
        case (0, 1): cfg.text = "Mode"; cell.accessoryView = seg
        case (0, 2): cfg.text = "Volume"; cell.accessoryView = slider
        case (0, 3): cfg.text = "General"; cell.accessoryType = .disclosureIndicator
        default:
            cfg.text = "Delete"
            cfg.textProperties.color = .systemRed
        }
        cell.contentConfiguration = cfg
        return cell
    }
}

final class DetailVC: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Detail"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never
    }
}

final class SheetVC: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = "Sheet"
        label.font = .preferredFont(forTextStyle: .title2)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
        ])
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
    }
}
