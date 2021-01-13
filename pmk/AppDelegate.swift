/*
 * Эмулятор советских ПМК для iOS -- (c) Xen, 2014
 *
 * AppDelegate.swift
 * Главный делегат приложения
 *
 */

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate
{
    var window: UIWindow?
    
    // Главный контроллер приложения, в котором находится эмулятор
    weak var mainViewController: MainViewController!
    
    // Временный дамп памяти
    private var temporaryDump: [UInt8]?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool
    {        
        // Запрещаем переход в сон
        application.idleTimerDisabled = true
        return true
    }

    func applicationDidEnterBackground(application: UIApplication)
    {
        // Сохраняем временный дамп и приостанавливаем работу калькулятора
        temporaryDump = mainViewController.emulator?.dump()
        mainViewController.emulator?.turnOff()
        mainViewController.emulator = nil
    }

    func applicationWillEnterForeground(application: UIApplication)
    {
        // Восстанавливаем состояние калькулятора из дампа
        if let dump = temporaryDump
        {
            mainViewController.createEmulator()
            mainViewController.emulator!.load(dump)
            mainViewController.emulator!.turnOn()
        }
    }

    // func applicationWillTerminate(application: UIApplication!) {
    //     // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    // }
}

