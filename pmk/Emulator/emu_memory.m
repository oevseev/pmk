/*
 * Эмулятор советских ПМК для iOS -- (c) Xen, 2014
 *
 * emu_memory.m
 * Программная эмуляция динамической памяти типа К745ИР2 (Objective-C, реализация)
 *
 */

#import "emu_memory.h"

@implementation Memory

- (void) tick:(uint8_t *)bus
{
    // Сохраняем текущую ячейку для последующего вывода на шину
    // и замещаем ее новым значением.
    uint8_t output = memory[_macroTick];
    memory[_macroTick] = *bus; *bus = output;
    
    // Проверяем индекс памяти на выход за границу массива, т.к.
    // память имеет циклическую структуру.
    if (++_macroTick >= 252) _macroTick = 0;
}

- (NSArray *) dump
{
    // Сжимаем память, умещая два ниббла в одном байте.
    NSMutableArray *ret = [[NSMutableArray alloc] init];
    for (int i = 0; i < 126; i++)
        [ret addObject:[NSNumber numberWithUnsignedChar:
                        ((memory[i*2] << 4) + memory[i*2 + 1])]];
    return ret;
}

- (void) load:(NSArray *)dump
{
    // Процесс обратен предыдущему.
    for (int i = 0; i < 126; i++)
    {
        uint8_t byte = [dump[i] unsignedCharValue];
        memory[i*2] = byte >> 4;
        memory[i*2 + 1] = byte & 0xF;
    }
}

@end