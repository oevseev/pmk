/*
 * Эмулятор советских ПМК для iOS -- (c) Xen, 2014
 *
 * LocalizationMacros.swift
 * Макросы локализации
 *
 */

import Foundation

func _l(string: String) -> String
{
    return NSBundle.mainBundle().localizedStringForKey(string, value: "", table: nil)
}