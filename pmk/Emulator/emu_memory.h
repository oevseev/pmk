/*
 * Эмулятор советских ПМК для iOS -- (c) Xen, 2014
 *
 * emu_memory.h
 * Программная эмуляция динамической памяти типа К745ИР2 (Objective-C, заголовок)
 *
 */

#import <Foundation/Foundation.h>

@interface Memory : NSObject
{
    // К745ИР2 представляет собой сдвиговый регистр емкостью 1024 бит,
    // но использоваться при этом могут лишь 1008 (252 ниббла).
    // В целях оптимизации ниббл (4 бита) представлен как uint8_t.

    @private
        uint8_t memory[252];        // Массив динамической памяти
    
    @public
        int _macroTick;             // Указатель шага динамической памяти.
}

@property (readonly) int macroTick;

- (void) tick:(uint8_t *)bus;  // Эмуляция такта динамической памяти
- (NSArray *) dump;            // Дамп памяти
- (void) load:(NSArray *)dump; // Загрузка дампа

@end