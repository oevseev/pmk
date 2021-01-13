/*
 * Эмулятор советских ПМК для iOS -- (c) Xen, 2014
 *
 * emu_mcu13.h
 * Программная эмуляция микроконтроллеров типа К745ИК13 (Objective-C, заголовок)
 *
 */

#import <Foundation/Foundation.h>
#import "emu_rom.h"

@interface MCU : NSObject
{
    @private
        // ПЗУ микроконтроллера
        struct ROM *rom;
    
        // Указатели команд
        int microPtr, macroPtr, synchroPtr;
    
        // Регистры оперативной памяти
        uint8_t M[42], R[42], ST[42];
    
        // Постоянные регистры:
        // * S  - регистр общего назначения
        // * S1 - регистр общего назначения
        // * L  - регистр переноса (5-й разряд сумматора)
        // * T  - регистр внешнего входа
        uint8_t S, S1, L, T;
    
        // Вспомогательный массив запятой
        bool rawComma[12];
    
    @public
        // Индикатор макротакта
        int _macroTick;
    
        // Внешние входы
        NSInteger _K1, _K2;
}

// Свойства с публичными полями
@property (readonly) int macroTick;
@property NSInteger K1;
@property NSInteger K2;

// Автоматически рассчитываемые свойства
@property (readonly) NSArray *display;  // Массив индикатора
@property (readonly) NSArray *comma;    // Массив запятой
@property (readonly) bool strobe;       // Стробовое состояние индикатора

- (id) initWithROM:(struct ROM *)rom;   // Инициализация с заданным ROM

- (void) tick:(uint8_t *)bus;           // Эмуляция такта контроллера
- (void) busInput:(uint8_t)bus;         // Получение данных с шины (без такта)
- (NSArray *) dump;                     // Дамп памяти
- (void) load:(NSArray *)dump;          // Загрузка дампа

@end