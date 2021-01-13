/*
 * Эмулятор советских ПМК для iOS -- (c) Xen, 2014
 *
 * MainViewController.swift
 * Контроллер главного вида (калькулятора)
 *
 */

import UIKit

class MainViewController: UIViewController
{
    // Элементы пользовательского интерфейса
    @IBOutlet var angleModeSlider: UISlider!
    @IBOutlet var backgroundImageView: UIImageView!
    @IBOutlet var displayView: DisplayView!
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var powerSwitch: UISwitch!
    
    // Вид клавиатуры
    var buttonView: UIView?
    
    // Объект эмулятора и его тип
    var emulator: Emulator?
    var currentType = ""
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Сообщаем о существовании текущего вида делегату приложения,
        // чтобы при открытии/закрытии приложения запускался/приостанавливался эмулятор.
        (UIApplication.sharedApplication().delegate as! AppDelegate).mainViewController = self
        
        // Скрываем дорожку у переключателя угловых величин
        angleModeSlider.setMinimumTrackImage(UIImage(), forState: .Normal)
        angleModeSlider.setMaximumTrackImage(UIImage(), forState: .Normal)
        
        // Если у нас на руках iPhone 4(S), уменьшаем высоту надписи с названием.
        if (UIScreen.mainScreen().bounds.height < 568)
        {
            (nameLabel.constraints()[0] as! NSLayoutConstraint).constant = 32
            nameLabel.frame.size = CGSizeMake(nameLabel.frame.width, 32)
        }
        
        setCalculatorType("MK61")
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?)
    {
        if segue.identifier!.hasPrefix("segueToFileManager")
        {
            ((segue.destinationViewController as! UINavigationController).viewControllers.first
                as! FileViewController).setFileManagerMode(isSaveMode: segue.identifier!.hasSuffix("Save"))
        }
    }
    
    private func setCalculatorType(type: String)
    {
        currentType = type
        
        // Удаляем предыдущую клавиатуру, если таковая есть
        buttonView?.removeFromSuperview()
        
        var nameLabelText = "ЭЛЕКТРОНИКА\u{2003}\u{2003}"
        switch type
        {
            // case "B334": nameLabelText += "Б3 \u{2013} 34"
            case "MK54": nameLabelText += "МК \u{2013} 54"
            case "MK61": nameLabelText += "МК \u{2013} 61"
            default:     nameLabelText = ""
        }
        nameLabel.text = nameLabelText
        
        // Для Б3-34 используем черный цвет надписи, т.к. сам калькулятор светлый.
        // nameLabel.textColor = type == "B334" ? UIColor.blackColor() : UIColor.whiteColor()
        
        // Изображение подбирается из xcassets в соответствии с типом калькулятора.
        backgroundImageView.image = UIImage(named: "Background-\(type)")
        
        // Так как Auto Layout очень плохо работает с элементами, расположенными в сетке,
        // подгружаем кнопки из отдельного XIB-файла. Как оказалось, такой подход удобен
        // при наличии дополнительных скинов.
        buttonView = NSBundle.mainBundle().loadNibNamed(
            "ButtonsView-\(type.substringToIndex(advance(type.startIndex, 2)))",
            owner: self, options: nil)[0] as? UIView
            
        // Устанавливаем положение кнопок ниже надписи с названием калькулятора.
        let buttonViewYOffset = nameLabel.frame.origin.y + nameLabel.frame.height
        buttonView!.frame = CGRectMake(0, buttonViewYOffset,
            UIScreen.mainScreen().bounds.width,
            UIScreen.mainScreen().bounds.height - buttonViewYOffset)
        view.addSubview(buttonView!)
        
        for subview in buttonView!.subviews
        {
            if let button = subview as? UIButton
            {
                // Задаем селектор нажатия, т.к. кнопки в XIB не связаны IBOutlet'ами.
                button.addTarget(self, action: "pressKey:", forControlEvents: .TouchDown)
            }
        }
        
        // Если эмулятор включен, перезапускаем его.
        if emulator != nil
        {
            emulator!.turnOff();
            createEmulator();
            emulator!.turnOn()
        }
    }
    
    // Создание объекта эмулятора
    func createEmulator()
    {
        emulator = Emulator()
    
        // Разворачиваем через !, так как эмулятор гарантированно существует.
        emulator!.displayView = self.displayView
        emulator!.is1306Enabled = currentType == "MK61"
        emulator!.switchMode(Int(angleModeSlider.value))
    }
    
    func pressKey(sender: UIButton)
    {
        emulator?.userInput(sender.tag)
    }
    
    @IBAction func togglePower(sender: UISwitch)
    {
        if sender.on
        {
            if emulator == nil
            {
                createEmulator()
                emulator!.turnOn()
            }
        }
        else
        {
            emulator?.turnOff()
            emulator = nil
        }
    }
    
    // Смена режима градусных величин
    @IBAction func changeMode(sender: UISlider)
    {
        // TODO: Переключение угловых величин, не отпуская рычажка.
        
        // Округляем значение UISlider, заставляя его повторять поведение
        // физического рычажка на настоящих калькуляторах.
        sender.setValue(roundf(sender.value), animated: true)
        emulator?.switchMode(Int(sender.value))
    }

    // Смена типа калькулятора
    @IBAction func сhangeCalculatorType()
    {
        let newType = currentType == "MK61" ? (type: "MK54", label: "МК-54") : (type: "MK61", label: "МК-61")
        
        let changeDialog = UIAlertController(title: _l("Выбор калькулятора"),
            message: NSString(format: _l("Изменить калькулятор на %@? Текущее состояние будет сброшено."), newType.label) as String,
            preferredStyle: .Alert)
        changeDialog.addAction(UIAlertAction(title: _l("Отменить"), style: .Cancel, handler: nil))
        changeDialog.addAction(UIAlertAction(title: _l("Изменить"), style: .Default)
            { [weak self] _ in self!.setCalculatorType(newType.type) }
        )
        
        presentViewController(changeDialog, animated: true, completion: nil)
    }
    
    @IBAction func showMenu()
    {
        let menuSheet = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
            
        menuSheet.addAction(UIAlertAction(title: _l("Загрузить"), style: .Default)
            { [weak self] _ in self!.performSegueWithIdentifier("segueToFileManagerLoad", sender: nil) }
        )
        
        menuSheet.addAction(UIAlertAction(title: _l("Сохранить"), style: .Default)
        {
            [weak self] _ in
            if self!.emulator == nil
            {
                let segueErrorAlert = UIAlertController(title: _l("Ошибка"),
                    message: _l("Сохранять состояние можно лишь при включеном калькуляторе."),
                    preferredStyle: .Alert)
                segueErrorAlert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
                self!.presentViewController(segueErrorAlert, animated: true, completion: nil)
            }
            else { self!.performSegueWithIdentifier("segueToFileManagerSave", sender: nil) }
        })
        
        /*
        menuSheet.addAction(UIAlertAction(title: _l("Инспектор"), style: .Default)
            { [weak self] _ in self!.performSegueWithIdentifier("segueToInspector", sender: nil) }
        )
        */
    
        menuSheet.addAction(UIAlertAction(title: _l("Отменить"), style: .Cancel, handler: nil))
        presentViewController(menuSheet, animated: true, completion: nil)
    }
}

