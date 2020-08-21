//
//  ViewController.swift
//  Timy
//
//  Created by Dima on 19.08.2020.
//  Copyright © 2020 Dima. All rights reserved.
//

import UIKit
import CoreData

class ViewController: UIViewController {
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var timerView: UIView!
    
    private var records = [NSManagedObject]()
    private var state: State = .stopped
    private var timerString = "00:00:00:00" {
        didSet {
            self.timerLabel.text = self.timerString
        }
    }
    
    private var frozenTime = 0.0
    
    weak var timer: Timer?
    var time: Double = 0 {
        didSet {
            DispatchQueue.global().async {
                DispatchQueue.main.async {
                    let timeString = String(format: "%.2f", self.time)
                    let milisecondString = (timeString[(timeString.index(timeString.startIndex, offsetBy: timeString.count - 2))...])
                    let hours = Int(self.time) / 3600
                    let hoursString = String(format: "%.2d", hours)
                    let minutes = Int(self.time) / 60 % 60
                    let minutesString = String(format: "%.2d", minutes)
                    let seconds = Int(self.time) % 60
                    let secondsString = String(format: "%.2d", seconds)
                    self.timerString = String("\(hoursString):\(minutesString):\(secondsString):\(milisecondString)")
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let managedContext = appDelegate.persistentContainer.viewContext
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Record")
        
        do  {
            let fetchedResults = try managedContext.fetch(fetchRequest) as? [NSManagedObject]
            if let results = fetchedResults {
                records = results
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        timer?.invalidate()
        tableView.dataSource = self
        tableView.delegate = self
        self.setupViewTaps()
        self.setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main, using: { [weak self] _ in
            if self?.state == .running {
                self?.timer?.invalidate()
                self?.frozenTime = Date().timeIntervalSinceReferenceDate
            }
        })
        
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main, using: { [weak self]  _ in
            if self?.frozenTime != 0.0 {
                self?.time += Date().timeIntervalSinceReferenceDate - self!.frozenTime
                self?.runTimer()
                self?.frozenTime = 0.0
            }
        })
    }
    
    func runTimer() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true, block: {
            [weak self] _ in
            self?.time+=0.01
        })
        RunLoop.main.add(timer!, forMode: .common)
        state = .running
    }
    
    @objc func viewTapped(_ sender: UITapGestureRecognizer) {
        if state == .running {
            timer?.invalidate()
            state = .paused
        } else {
            runTimer()
        }
    }
    
    @objc func viewDoubleTapped(_ sender: UITapGestureRecognizer) {
        timer?.invalidate()
        state = .stopped
        createAlert()
    }
    
    private func setupViewTaps() {
        let viewTap = UITapGestureRecognizer(target: self, action: #selector(self.viewTapped(_:)))
        self.timerView.isUserInteractionEnabled = true
        self.timerView.addGestureRecognizer(viewTap)
        
        let viewDoubleTap = UITapGestureRecognizer(target: self, action: #selector(self.viewDoubleTapped(_:)))
        self.timerView.isUserInteractionEnabled = true
        viewDoubleTap.numberOfTapsRequired = 2
        self.timerView.addGestureRecognizer(viewDoubleTap)
        
        viewTap.require(toFail: viewDoubleTap)
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return records.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "recordCellID", for: indexPath)
        cell.textLabel?.textColor = .white
        let record = records[indexPath.row]
        if let recordTime = record.value(forKey: "time") as? String, let recordNote = record.value(forKey: "note") as? String {
            cell.textLabel?.text = "\(recordTime)   \(recordNote)"
        }
        return cell
    }
}

extension ViewController {
    
    func createAlert() {
        
        let alert = UIAlertController(title: "New record", message: "Enter note", preferredStyle: .alert)
        let addAction = UIAlertAction(title: "Add", style: .default, handler: { (action) -> Void in
            let note = alert.textFields![0].text ?? ""
            self.addRecord(time: self.timerString, note: note)
            self.tableView.reloadData()
            self.time = 0
        })
        alert.addTextField { (textField: UITextField) in
            textField.placeholder = "Note(Optional)"
        }
        alert.addAction(addAction)
        self.present(alert, animated: true, completion: nil)
    }
    
    func addRecord(time: String, note: String) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        let managedContext = appDelegate.persistentContainer.viewContext
        
        let entity = NSEntityDescription.entity(forEntityName: "Record", in: managedContext)
        
        let record = NSManagedObject(entity: entity!, insertInto: managedContext)
        
        record.setValue(time, forKey: "time")
        record.setValue(note, forKey: "note")
        
        do {
            try managedContext.save()
        } catch {
            print(error.localizedDescription)
        }
        
        records.append(record)
    }
}
