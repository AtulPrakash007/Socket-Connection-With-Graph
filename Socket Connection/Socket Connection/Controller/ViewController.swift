//
//  ViewController.swift
//  Socket Connection
//
//  Created by Mac on 5/8/17.
//  Copyright © 2017 AtulPrakash. All rights reserved.
//

import UIKit
import UserNotifications
import QuartzCore
import SwiftCharts

class ViewController: UIViewController {
    
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    var streamedNumbers: [StreamedNumber] = []
    
    var previousNumber:String = ""
    fileprivate var chart: Chart? // arc
    
    var isFirstTimeNotificaton:Bool = true
    var isFirstTimeLoading:Bool = true
    var graphPointArray = [Int]()
    var chartPointArray = [(Int,Int)]()
    
    var reachability: Reachability? = Reachability.networkReachabilityForInternetConnection()
    
    @IBOutlet weak var networkIssueView: UIView!
    @IBOutlet weak var loadingLbl: UILabel!
    @IBOutlet weak var numberLbl: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityDidChange(_:)), name: NSNotification.Name(rawValue: ReachabilityDidChangeNotificationName), object: nil)
        
        _ = reachability?.startNotifier()

        UNUserNotificationCenter.current().delegate = self
        
        SocketIOManager.sharedInstance.delegate = self
        SocketIOManager.sharedInstance.fetchRandomNumber()
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.currentStreamedNumber(_:)), name: NSNotification.Name(rawValue: "currentStreamedNumber"), object: nil)
        loadingLbl.isHidden = false
        getDataAndLoadChart()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkReachability()
    }
    
    func checkReachability() {
        guard let r = reachability else { return }
        if r.isReachable  {
            networkIssueView.isHidden = true
            print("Network Available")
        } else {
            networkIssueView.isHidden = false
            print("Network Unavailable")
        }
    }
  
    //------------------------------------------
    //MARK: Notification Center Methods
    //------------------------------------------
    
    func reachabilityDidChange(_ notification: Notification) {
        checkReachability()
    }
    
    // Notification is received and get the streamed Number
    func currentStreamedNumber(_ notification: Notification) {
        let streamedNumber = notification.object as! String
        if isFirstTimeNotificaton {
            isFirstTimeNotificaton = !isFirstTimeNotificaton
            previousNumber = streamedNumber
        }else{
            if previousNumber == streamedNumber {
                scheduleNotification(withNumber: previousNumber)
            }else{
                previousNumber = streamedNumber
            }
        }
        
        getDataAndLoadChart()
    }
    
    // Data is fetched from DB and Stored in Array
    // Load Chart is called by creating proper Array
    func getDataAndLoadChart() -> Void {
        
        if isFirstTimeLoading {
            getData()
            print(streamedNumbers)
            if streamedNumbers.count == 0 {
                loadingLbl.isHidden = false
                return
            }
            for i in 0 ... streamedNumbers.count-1 {
                print("\(streamedNumbers[i].streamed_number!) & \(streamedNumbers[i].number_date!)")
                
                graphPointArray.append(Int(streamedNumbers[i].streamed_number!)!)
                if graphPointArray.count > 9 {
                    graphPointArray.remove(at: 0)
                }
            }
            
            for i in 0 ... graphPointArray.count-1 {
                let dictionary = (graphPointArray[i],i+1)
                print(dictionary)
                chartPointArray.append(dictionary)
            }
            print(chartPointArray)
            loadingLbl.isHidden = true
            loadChart()
            isFirstTimeLoading = !isFirstTimeLoading
        }else{
            graphPointArray.append(Int(previousNumber)!)
            if graphPointArray.count > 9 {
                graphPointArray.remove(at: 0)
            }
        
            chartPointArray.removeAll()
            for i in 0 ... graphPointArray.count-1 {
                let dictionary = (graphPointArray[i],i+1)
                print(dictionary)
                chartPointArray.append(dictionary)
            }
            print(chartPointArray)
            loadingLbl.isHidden = true
            chart?.view.removeFromSuperview()
            loadChart()
        }
        
    }
    
    //The chart is loaded from here
    func loadChart() -> Void {
        let labelSettings = ChartLabelSettings(font: ChartDefaults.labelFont)
        
        let chartPoints = chartPointArray.map{ChartPoint(x:ChartAxisValueInt($0.0, labelSettings: labelSettings) , y: ChartAxisValueInt($0.1))}
        
        let xValues = ChartAxisValuesStaticGenerator.generateXAxisValuesWithChartPoints(chartPoints, minSegmentCount: 0, maxSegmentCount: 10, multiple: 1, axisValueGenerator: {ChartAxisValueDouble($0, labelSettings: labelSettings)}, addPaddingSegmentIfEdge: false)
        let yValues = ChartAxisValuesStaticGenerator.generateYAxisValuesWithChartPoints(chartPoints, minSegmentCount: 0, maxSegmentCount: 10, multiple: 1, axisValueGenerator: {ChartAxisValueDouble($0, labelSettings: labelSettings)}, addPaddingSegmentIfEdge: false)
        
        let xModel = ChartAxisModel(axisValues: xValues , axisTitleLabel: ChartAxisLabel(text: "Streamed Number", settings: labelSettings))
        let yModel = ChartAxisModel(axisValues: yValues, axisTitleLabel: ChartAxisLabel(text: "Y - Axis", settings: labelSettings))
        
        let chartFrame = ChartDefaults.chartFrame(view.bounds)
        
        let chartSettings = ChartDefaults.chartSettingsWithPanZoom
        
        let coordsSpace = ChartCoordsSpaceLeftBottomSingleAxis(chartSettings: chartSettings, chartFrame: chartFrame, xModel: xModel, yModel: yModel)
        let (xAxisLayer, yAxisLayer, innerFrame) = (coordsSpace.xAxisLayer, coordsSpace.yAxisLayer, coordsSpace.chartInnerFrame)
        
        let lineModel = ChartLineModel(chartPoints: chartPoints, lineColor: UIColor.purple, lineWidth: 2, animDuration: 1, animDelay: 0)
        let chartPointsLineLayer = ChartPointsLineLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, lineModels: [lineModel], pathGenerator: CatmullPathGenerator()) // || CubicLinePathGenerator
        
        let settings = ChartGuideLinesDottedLayerSettings(linesColor: UIColor.black, linesWidth: ChartDefaults.guidelinesWidth)
        let guidelinesLayer = ChartGuideLinesDottedLayer(xAxisLayer: xAxisLayer, yAxisLayer: yAxisLayer, settings: settings)
        
        let chart = Chart(
            frame: chartFrame,
            innerFrame: innerFrame,
            settings: chartSettings,
            layers: [
                xAxisLayer,
                yAxisLayer,
                guidelinesLayer,
                chartPointsLineLayer
            ]
        )
        
        view.addSubview(chart.view)
        self.chart = chart
    }
    
    
    // Schedule the Notifications with repeat
    func scheduleNotification(withNumber number:String) {

        print("Schedule Notification for number: \(number)")
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
        
        // Schedule the notification ********************************************
        let content = UNMutableNotificationContent()
        content.title = "Found a match sequence of number \(previousNumber)"
        content.body = "Tap to see the spline chart"
        content.sound = UNNotificationSound(named: "Notification Sound.wav")
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5,
                                                        repeats: false)

        let identifier = "LocalNotification"
        let request = UNNotificationRequest(identifier: identifier,
                                            content: content, trigger: trigger)
        center.add(request, withCompletionHandler: { (error) in
            if error != nil {
                print(error?.localizedDescription ?? "")
                // Something went wrong
            }
        })
    }
    
    func getData() {
        do {
            streamedNumbers = try context.fetch(StreamedNumber.fetchRequest())
        }
        catch {
            print("Fetching Failed")
        }
    }
    
    @IBAction func refreshBtnAction(_ sender: Any) {
        checkReachability()
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        reachability?.stopNotifier()
    }
}

extension ViewController: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // some other way of handling notification
        completionHandler([.alert, .sound])
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
       //If any category action is defined
        //In that case use response.actionIdentifer in switch case and handle the action
        completionHandler()
    }
}

extension ViewController:SocketIOManagerDelegate {
    func fetchedNumber(_ number:String){
        numberLbl.text = number
    }
}

