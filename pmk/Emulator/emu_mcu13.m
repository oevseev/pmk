/*
 * Эмулятор советских ПМК для iOS -- (c) Xen, 2014
 *
 * emu_mcu13.m
 * Программная эмуляция микроконтроллеров типа К745ИК13 (Objective-C, реализация)
 *
 */

#import "emu_mcu13.h"

// Вспомогательный массив прыжков
const int j[] =
{
    0, 1, 2, 3, 4, 5,
    3, 4, 5, 3, 4, 5,
    3, 4, 5, 3, 4, 5,
    3, 4, 5, 3, 4, 5,
    6, 7, 8, 0, 1, 2,
    3, 4, 5, 6, 7, 8,
    0, 1, 2, 3, 4, 5
};

@implementation MCU : NSObject

- (id) initWithROM:(struct ROM *)_rom
{
    self = [super init];
    rom = _rom;
    return self;
}

- (NSArray *) comma
{
    // На индикаторе массив запятых представляется в другом порядке: сначала
    // идут (слева направо) индексы [8; 0], затем - [11; 9].
    
    NSMutableArray *commaArray = [[NSMutableArray alloc] init];
    for (int i = 0; i < 12; i++) {
        int commaIndex = (i < 9) ? (8 - i) : (11 - (i - 9));
        [commaArray addObject:[NSNumber numberWithBool: rawComma[commaIndex]]];
    }
    return commaArray;
}

- (NSArray *) display
{
    // На индикаторе массив цифр представляется аналогично предыдущему случаю.
    
    NSMutableArray *dispArray = [[NSMutableArray alloc] init];
    for (int i = 0; i < 12; i++) {
        int dispIndex = (i < 9) ? (8 - i) : (11 - (i - 9));
        [dispArray addObject:[NSNumber numberWithInt: R[dispIndex * 3]]];
    }
    return dispArray;
}

- (bool) strobe
{
    // Стробовое состояние (выводится ли содержиое регистра X на индикатор)
    return !(rom->macro[macroPtr] & 0xFC0000);
}

- (void) tick:(uint8_t *)bus
{
    // Если цикл только начался, устанавливаем указатель макрокоманды,
    // находящийся соответственно в ячейках 36 и 39 регистра R.
    if (!_macroTick)
    {
        macroPtr = R[36] + 16 * R[39];
        if (self.strobe) T = 0;
    }
    
    // Установка синхропрограммы и модификатора.
    // Адрес синхропрограммы определяется макрокомандой и его положение
    // зависит от выполняемого сейчас макротакта.
    if      (_macroTick / 9 <= 2) synchroPtr = rom->macro[macroPtr] & 0xFF;
    else if (_macroTick / 9 == 3) synchroPtr = rom->macro[macroPtr] >> 8 & 0xFF;
    else if (_macroTick / 9 == 4)
    {
        synchroPtr = rom->macro[macroPtr] >> 16 & 0xFF;
        if (synchroPtr > 0x1F)
        {
            // Сохранение адреса команды для следующего цикла
            if (_macroTick == 36)
            {
                R[37] = synchroPtr & 0xF;
                R[40] = synchroPtr >> 4;
            }
            synchroPtr = 0x5F;
        }
    }
    int mod = 0xFF & rom->macro[macroPtr] >> 24;
    
    // Переход к следующей микрокоманде
    microPtr = rom->synchro[synchroPtr * 9 + j[_macroTick]] & 0x3F;
    if (microPtr >= 60)
    {
        microPtr = (microPtr - 60) * 2;
        if (!L) microPtr++; microPtr += 60;
    }
    int microCmd = rom->micro[microPtr];
    
    /*
     * Обработка микрокоманды
     * Тут для меня начинается темный лес, я пока здесь ничего не понимаю.
     * Может быть, потом эта часть обрастет комментариями, но это будет,
     * как мне кажется, очень даже нескоро.
     *
     * UPD: Почитал Трохименко, закомментировал. Стало немного понятнее,
     * но я не специалист по микроконтроллерам, и до сих удивляюсь, каким
     * магическим образом работают микрокоманды и почему именно так выбраны
     * входы и константы.
     */
    
    // Инициализация входов сумматора
    uint8_t A = 0, B = 0, G = 0;
    
    // Обработка микрокоманды и подача данных на вход сумматора.
    // На вход A сумматора могут быть поданы R, M, S, ~R, (0xA * ~L), S и константа 4.
    if (microCmd & 1 ) A |= R[_macroTick];
    if (microCmd & 2 ) A |= M[_macroTick];
    if (microCmd & 4 ) A |= ST[_macroTick];
    if (microCmd & 8 ) A |= ~R[_macroTick] & 0xF;
    if (microCmd & 16) if (!L) A |= 0xA;
    if (microCmd & 32) A |= S;
    if (microCmd & 64) A |= 0x4;
    
    // Обработка ввода-вывода (cигналы 0b10 и 0b11 поля регистра S1)
    // В книге Трохименко описание отсутствует, поэтому просто надеюсь,
    // что данный код будет работать. Не я же его писал.
    if ((microCmd >> 24 & 2) && (_macroTick / 3 != _K1 - 1) && (_K2)) S1 |= _K2;
    
    // На вход B могут быть поданы S, ~S, S1 и константы 6 и 1.
    if (microCmd >> 7 & 1 ) B |= S;
    if (microCmd >> 7 & 2 ) B |= ~S & 0xF;
    if (microCmd >> 7 & 4 ) B |= S1;
    if (microCmd >> 7 & 8 ) B |= 0x6;
    if (microCmd >> 7 & 16) B |= 0x1;

    // Продолжение обработки ввода-вывода
    // Опять же, оригинальный код разбит на две части и расположен вокруг кода обработки
    // входа B. Что послужило тому причиной - неизвестно, т.к. код при объединении все равно
    // продолжает работать; но ради обеспечения совместимости оставлен как есть.
    if (self.strobe)
    {
        if (_macroTick / 3 == _K1 - 1)
        {
            if (_K2)
            {
                S1 = _K2;
                T = 1;
            }
        }
        if (_macroTick / 3 >= 1 && _macroTick / 3 <= 12)
            rawComma[_macroTick / 3 - 1] = L > 0;
    }
    else if (!_K2) T = 0;
    
    // На вход G (перенос) могут быть поданы L, ~L, T
    if (microCmd >> 12 & 1) G |= L & 1;
    if (microCmd >> 12 & 2) G |= ~L & 1;
    if (microCmd >> 12 & 4) G = ~T & 1;
    
    // Непосредственно суммирование
    int sum = A + B + G;
    int sigma = sum & 0xF;
    int P = sum >> 4; // Перенос
    
    // Обработка кода перессылки результата в регистр R
    if (!mod || _macroTick >= 36)
    {
        switch (microCmd >> 15 & 0x7)
        {
            // case 0:
            case 1: R[_macroTick] = R[(_macroTick + 3) % 42];   break;
            case 2: R[_macroTick] = sigma;                      break;
            case 3: R[_macroTick] = S;                          break;
            case 4: R[_macroTick] = R[_macroTick] | S | sigma;  break;
            case 5: R[_macroTick] = S | sigma;                  break;
            case 6: R[_macroTick] = R[_macroTick] | S;          break;
            case 7: R[_macroTick] = R[_macroTick] | sigma;      break;
        }
        if (microCmd >> 18 & 1) R[(_macroTick + 41) % 42] = sigma; // R(I-1)
        if (microCmd >> 19 & 1) R[(_macroTick + 40) % 42] = sigma; // R(I-2)
    }
    
    if (microCmd >> 20 & 1) M[_macroTick] = S; // Установка регистра памяти M
    if (microCmd >> 21 & 1) L = 1 & P; // Установка регистра переноса
    
    // Установка регистра S
    switch (microCmd >> 22 & 0x3)
    {
        // case 0:
        case 1: S = S1;         break;
        case 2: S = sigma;      break;
        case 3: S = S1 | sigma; break;
    }
    
    // Установка регистра S1
    switch (microCmd >> 24 & 0x3)
    {
        // case 0:
        case 1: S1 = sigma; break;
        // case 2 - S1 | H, но это было уже произведено ранее
        case 3: S1 |= sigma; break; // S1 | H | sigma
    }
    
    // Установка регистра ST
    int x = 0, y = 0, z = 0;
    switch (microCmd >> 26 & 0x3)
    {
    // case 0:
    case 1:
        ST[(_macroTick + 2) % 42] = ST[(_macroTick + 1) % 42];
        ST[(_macroTick + 1) % 42] = ST[_macroTick];
        ST[_macroTick] = sigma;
        break;
    case 2:
        x = ST[_macroTick];
        ST[_macroTick] = ST[(_macroTick + 1) % 42];
        ST[(_macroTick + 1) % 42] = ST[(_macroTick + 2) % 42];
        ST[(_macroTick + 2) % 42] = x;
        break;
    case 3:
        x = ST[_macroTick];
        y = ST[(_macroTick + 1) % 42];
        z = ST[(_macroTick + 2) % 42];
        ST[_macroTick % 42] = sigma | y;
        ST[(_macroTick + 1) % 42] = x | z;
        ST[(_macroTick + 2) % 42] = y | x;
        break;
    }
    
    // Передача управления в шину
    int ret = M[_macroTick] & 0xF;
    M[_macroTick] = *bus; *bus = ret;
    
    // Переход на следующий макротакт
    if (++_macroTick >= 42) _macroTick = 0;
}

- (void) busInput:(uint8_t)bus
{
    M[(_macroTick + 41) % 42] = bus;
}

// Дамп всех регистров памяти.
// Должен производиться в начале/конце цикла, так как указатели,
// входы и выходы не сохраняются.
- (NSArray *) dump
{
    NSMutableArray *dumpArray = [[NSMutableArray alloc] init];
    
    // Сохранение значащих регистров будем производить следующим образом:
    // дамп будет содержать 21 трехбайтовую группу, каждая из которых состоит
    // по двум нибблам с индексами 2i и 2i + 1 из каждого регистра.
    for (int i = 0; i < 21; i++)
    {
        [dumpArray addObject: [NSNumber numberWithUnsignedChar: ( M[2*i] << 4) +  M[2*i + 1]]];
        [dumpArray addObject: [NSNumber numberWithUnsignedChar: ( R[2*i] << 4) +  R[2*i + 1]]];
        [dumpArray addObject: [NSNumber numberWithUnsignedChar: (ST[2*i] << 4) + ST[2*i + 1]]];
    }
    
    // Сохранение общих регистров.
    // Каждый регистр может содержать ниббл (4 бита) информации,
    // поэтому итоговый объем данных, занимаемых ими - 2 байта.
    [dumpArray addObject: [NSNumber numberWithUnsignedChar: (S << 4) + S1]];
    [dumpArray addObject: [NSNumber numberWithUnsignedChar: (L << 4) + T ]];
    
    // Возвращаем полученный дамп (65 байтов).
    return dumpArray;
}

// Загрузка из дампа
// Как и дамп, должна производиться в начале/конце цикла.
- (void) load:(NSArray *)dump
{
    // Процесс обратен предыдущему и в объяснении не нуждается.
    for (int i = 0; i < 21; i++)
    {
         M[2*i] = [dump[i*3    ] unsignedCharValue] >> 4;  M[2*i + 1] = [dump[i*3    ] unsignedCharValue] & 0xF;
         R[2*i] = [dump[i*3 + 1] unsignedCharValue] >> 4;  R[2*i + 1] = [dump[i*3 + 1] unsignedCharValue] & 0xF;
        ST[2*i] = [dump[i*3 + 2] unsignedCharValue] >> 4; ST[2*i + 1] = [dump[i*3 + 2] unsignedCharValue] & 0xF;
    }
    
    S = [dump[21] unsignedCharValue] >> 4; S1 = [dump[21] unsignedCharValue] & 0xF;
    L = [dump[22] unsignedCharValue] >> 4;  T = [dump[22] unsignedCharValue] & 0xF;
}

@end
