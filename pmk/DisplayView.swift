/*
 * Эмулятор советских ПМК для iOS -- (c) Xen, 2014
 *
 * DisplayView.swift
 * Вид индикатора
 *
 */

import UIKit

class DisplayView : UIView
{
    // TODO: Можно добавить шестнадцатеричную нотацию.
    private let font: [UInt8] =
    [
        0b0111111, 0b0000110, 0b1011011, 0b1001111,
        0b1100110, 0b1101101, 0b1111101, 0b0000111,
        0b1111111, 0b1101111, 0b1000000, 0b0111000,
        0b0111001, 0b0110001, 0b1111001, 0b0000000
    ]
    
    // Массив цифр индикатора
    private var digitArray = [[UIImageView]]()
    
    // Буфер (для облегчения нагрузки на UI)
    private var displayBuffer = [Int]()
    private var commaBuffer = [Bool]()
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        prepareDisplay()
    }
    required init(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        prepareDisplay()
    }
    
    // TODO: Добавить возможность красить индикатор цветом.
    // Функция, приводящая индикатор в презентабельный вид
    private func prepareDisplay()
    {
        // Закругленные края
        layer.masksToBounds = true
        layer.cornerRadius = 4
        
        for digitIndex in 0..<12
        {
            // Каждая цифра имеет размер 24x30 пикселей, отстоит на 10
            // пикселей от верха и на 5 - от края или соседней цифры.
            let digitFrame = CGRectMake(CGFloat(5 + 24 * digitIndex), 10, 24, 30)
            
            let segmentBackground = UIImageView()
            segmentBackground.frame = digitFrame
            segmentBackground.image = UIImage(named: "SegmentBg")
            addSubview(segmentBackground)
            
            var segmentArray = [UIImageView]()
            for segmentIndex in 0..<8
            {
                let segment = UIImageView()
                segment.frame = digitFrame
                
                // Так как сегмент обозначается буквой, переводим числовой код сегмента в буквенный,
                // прибавляя к нему 'A' (0x41). Десятичная точка обозначена буквой H.
                segment.image = UIImage(named: "Segment\(String(UnicodeScalar(0x41 + segmentIndex)))")
                
                // Скрываем сегмент до определенного момента.
                segment.hidden = true
                
                segmentArray += [segment]
                addSubview(segment)
            }
            
            digitArray += [segmentArray]
        }
    }
    
    // Вывод состояния дисплея
    func setDisplay(display: [Int], comma: [Bool])
    {
        if displayBuffer != display || commaBuffer != comma
        {
            // Буферизированный вывод, чтобы не перегружать индикатор
            displayBuffer = display
            commaBuffer = comma
            
            dispatch_sync(dispatch_get_main_queue())
            {
                for digitIndex in 0..<12
                {
                    // Переводим данные из двух массивов в набор сегментов для рисования.
                    // Примечание: Swift ругается на UInt8(Bool), поэтому приходится ставить тернарный оператор.
                    let digitToDraw = self.font[display[digitIndex]] | (comma[digitIndex] ? 1 : 0) << 7
                
                    // Устанавливаем видимость соответствующих элементов.
                    for segmentIndex in 0..<8
                    {
                        // Не очень-то мне и нравится вся эта хрень с явным приведением типов ;__;
                        // А с thread safety - и подавно, убил час на эту хрень T__T
                        self.digitArray[digitIndex][segmentIndex].hidden = digitToDraw >> UInt8(segmentIndex) & 1 == 0
                    }
                }
            }
        }
    }
    
    // Очистка состояния дисплея (обычно вызывается с задержкой на несколько тактов)
    func wipeDisplay()
    {
        setDisplay([Int ](count: 12, repeatedValue: 0xF),
            comma: [Bool](count: 12, repeatedValue: false))
    }
}
