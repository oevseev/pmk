/*
 * Эмулятор советских ПМК для iOS -- (c) Xen, 2014
 *
 * InspectorTabBarController.swift
 * Контроллер вида со вкладками (инспектор)
 *
 */

import UIKit

class InspectorTabBarController: UITabBarController
{
    @IBAction func closeView()
    {
        dismissViewControllerAnimated(true, completion: nil)
    }
}
