/*
 * Эмулятор советских ПМК для iOS -- (c) Xen, 2014
 *
 * emulator.swift
 * Потоковый объект эмулятора
 *
 */

import Foundation

// Мера угла
enum AngleMode : Int
{
	case Radians = 0
	case Grads
	case Degrees
}

class Emulator : NSThread
{
	// Объект индикатора
	weak var displayView: DisplayView!
    
    // Поддерживается ли К745ИК1306
    var is1306Enabled = false
    
    // Запущен ли поток эмулятора
    private var isRunning = false
    
    // Разрешен ли дамп/загрузка
    private let cycleCondition = NSCondition()
    private var isIOAllowed = true

	// Буферы входных данных
	private var angleMode: AngleMode = .Radians // Рычажок меры угла
	private var keyPressed = 0 // Код нажатой клавиши

	// Микроконтроллеры
	private let mcu1302 = MCU(ROM: &mcu1302_rom),
                mcu1303 = MCU(ROM: &mcu1303_rom),
                mcu1306 = MCU(ROM: &mcu1306_rom)

	// Массивы памяти
	private let mem1 = Memory(),
                mem2 = Memory()
    
    // Включение эмулятора
    func turnOn()
    {
        isRunning = true
        start()
    }
    
    // Выключение эмулятора
    func turnOff()
    {
        // Просто помечаем эмулятор как выключенный, при этом выполнение
        // потока должно покинуть цикл и завершиться.
        isRunning = false
    }
    
    // Дамп памяти
    func dump() -> [UInt8]
    {
       // Ждем конца цикла, если он запущен
        cycleCondition.lock()
        while !isIOAllowed
            { cycleCondition.wait() }

        let dumpArray = mcu1302.dump() + mcu1303.dump() +
             mcu1306.dump() + mem1.dump() + mem2.dump()
        
        // Разблокируем поток и возвращаем дамп
        cycleCondition.unlock()
        return map(dumpArray) { $0.unsignedCharValue }
    }
    
    // Загрузка дампа памяти
    func load(dumpArray: [UInt8])
    {
        // Процесс полностью аналогичен предыдущему,
        // только здесь происходит не сохранение, а загрузка.
        cycleCondition.lock()
        while !isIOAllowed
            { cycleCondition.wait() }
        
        // Переводим [UInt8] в [NSNumber].
        let objcArray: NSArray = map(dumpArray) { NSNumber(unsignedChar: $0) }
        
        mcu1302.load(objcArray.subarrayWithRange(NSRange(location:   0, length:  65)))
        mcu1303.load(objcArray.subarrayWithRange(NSRange(location:  65, length:  65)))
        mcu1306.load(objcArray.subarrayWithRange(NSRange(location: 130, length:  65)))
           mem1.load(objcArray.subarrayWithRange(NSRange(location: 195, length: 126)))
           mem2.load(objcArray.subarrayWithRange(NSRange(location: 321, length: 126)))
        
        cycleCondition.unlock()
    }
    
    // Пользовательский ввод
    func userInput(code: Int)
    {
        keyPressed = code
    }
    
    // Обработка переключателя угловых величин
    func switchMode(rawMode: Int)
    {
        // Защита от дурака (хотя кому она здесь нужна?)
        if let newMode = AngleMode(rawValue: rawMode)
            { angleMode = newMode }
    }

	// Главный цикл потока
	override func main()
	{
		// Шина данных
		var bus: UInt8 = 0
        
        // Счетчик пустых тактов (для правильной реализации мерцания)
        var emptyIterationsCounter = 0

		// Установка входа K2 у К745ИК1303 (всегда 1)
		mcu1303.K2 = 1

		while (isRunning || !isIOAllowed)
		{
            // Запрет обмена данными во время эмуляции цикла (это также касается работы
            // с отладчиком и прямого просмотра/редактирования регистров).
            if isIOAllowed
            {
                isIOAllowed = false
                cycleCondition.lock()
            }
            
            // Обработка нажатия клавиши (входной байт разделяется
            // на два ниббла и передается на входы К745ИК1302)
			if keyPressed > 0
			{
				mcu1302.K1 = keyPressed & 0b1111
				mcu1302.K2 = keyPressed >> 4 & 0b1111
                keyPressed = 0
			}

            // Выбор угловой величины и его передача на вход К745ИК1303
			switch angleMode
            {
                case .Radians: mcu1303.K1 = 0b1010
                case .Grads  : mcu1303.K1 = 0b1100
                case .Degrees: mcu1303.K1 = 0b1011
            }
            
			// Эмуляция полного цикла
			for _ in 0..<42
			{
                mcu1302.tick(&bus); mcu1303.tick(&bus); if is1306Enabled { mcu1306.tick(&bus) }
                mem1.tick(&bus); mem2.tick(&bus); mcu1302.busInput(bus)
			}
            
            // Освобождаем входы для последующего ввода (иначе будет невозможен последующий ввод)
            if mcu1302.strobe
            {
                mcu1302.K1 = 0
                mcu1302.K2 = 0
            }
            
            // Ради обеспечения совместимости и упрощения кода открываем мьютекс только при том
            // условии, что фазы микроконтроллеров и регистров памяти совпадают.
            if mcu1302.macroTick == 0 && mem1.macroTick == 0
            {
                isIOAllowed = true
                cycleCondition.signal()
                cycleCondition.unlock()
            }
            
            // Вывод состояния дисплея на индикатор, а также реализация (при необходимости)
            // задержки между тактами, учитывая время, затраченное на обновление дисплея.
            let timeStartedUpdatingDisplay = CFAbsoluteTimeGetCurrent()
            if mcu1302.strobe
            {
                emptyIterationsCounter = 0
                displayView.setDisplay(mcu1302.display as! [Int], comma: mcu1302.comma as! [Bool])
            }
            else
            {
                // Пропускаем несколько "пустых" тактов ради правильной реализации мерцания индикатора.
                if emptyIterationsCounter++ > 10 { displayView.wipeDisplay() }
            }
            usleep(max(0, 1250 - Int(CFAbsoluteTimeGetCurrent() - timeStartedUpdatingDisplay)))
        }
        
        displayView.wipeDisplay()
	}
}
