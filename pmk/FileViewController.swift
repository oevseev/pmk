/*
 * Эмулятор советских ПМК для iOS -- (c) Xen, 2014
 *
 * FileViewController.swift
 * Контроллер вида сохранения
 *
 */

import UIKit

class FileViewController: UIViewController, UITableViewDataSource, UITableViewDelegate
{
    // Путь к директории с сохранениями
    private var documentDirectory: String!
    
    // Список названий файлов и словарь с их содержимым
    private var fileNames: [String]!
    private var fileData: [String: (description: String?, memoryDump: [UInt8])]! = [:]
    
    // Расширение файла сохранения — файлы с данным расширением будут показываться в менеджере сохранений.
    private let dumpFileExtension = ".pmk"
    
    // Режим файлового менеджера (сохранение или загрузка)
    private var isSaveMode = true
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Сохранения ищем в стандартной sandbox'овской папке Documents,
        // возвращаемый тип гарантируемо транслируется в строку.
        documentDirectory = NSSearchPathForDirectoriesInDomains(
            .DocumentDirectory, .UserDomainMask, /* expandTilde */ true)[0] as! String
        
        // Обновляем список файлов
        reloadFileList()
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        var cell: UITableViewCell!
        
        if let description = fileData[fileNames[indexPath.row]]?.description
        {
            cell = UITableViewCell(style: .Subtitle, reuseIdentifier: nil)
            cell.detailTextLabel!.text = description;
            cell.detailTextLabel!.textColor = UIColor(white: 0.8, alpha: 1)
        }
        else
        {
            cell = UITableViewCell(style: .Default, reuseIdentifier: nil)
        }
        
        cell.backgroundColor = UIColor(white: 0.25, alpha: 1)
        cell.textLabel!.text = fileNames[indexPath.row];
        cell.textLabel!.textColor = UIColor.whiteColor()
        
        return cell
    }
    
    func tableView(tableView: UITableView,
        commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath)
    {
        if editingStyle == .Delete
        {
            NSFileManager.defaultManager().removeItemAtPath(
                documentDirectory.stringByAppendingPathComponent(
                fileNames[indexPath.row] + dumpFileExtension), error: nil)
            fileData.removeValueForKey(fileNames[indexPath.row])
            fileNames.removeAtIndex(indexPath.row)
            tableView.deleteRowsAtIndexPaths([indexPath],
                withRowAnimation: .Fade) // не reloadData, ибо будет EXC_BAD_ACCESS
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        let mvc = (UIApplication.sharedApplication().delegate as! AppDelegate).mainViewController!
        
        if !isSaveMode
        {
            let loadDialog = UIAlertController(
                title: fileNames[indexPath.row], message: fileData[fileNames[indexPath.row]]!.description, preferredStyle: .Alert)
            
            loadDialog.addAction(UIAlertAction(
                title: _l("Отменить"), style: .Cancel, handler: nil))
            loadDialog.addAction(UIAlertAction(title: _l("Загрузить"), style: .Default)
            {
                [weak self] _ in
                
                // Если у нас уже существовал эмулятор, отключаем его.
                mvc.emulator?.turnOff()
                mvc.emulator = nil
                
                // Создаем новый объект эмулятора.
                mvc.createEmulator()
                mvc.emulator!.load(self!.fileData[self!.fileNames[indexPath.row]]!.memoryDump)
                mvc.emulator!.turnOn()
                
                // Возвращаем управление в главный контроллер.
                mvc.powerSwitch.setOn(true, animated: true)
                self!.dismissViewControllerAnimated(true, completion: nil)
            })
            
            presentViewController(loadDialog, animated: true, completion: nil)
        }
        else
        {
            let rewriteDialog = UIAlertController(
                title: _l("Сохранение"),
                message: _l("Вы действительно хотите перезаписать имеющийся файл?"),
                preferredStyle: .Alert)
            rewriteDialog.addAction(UIAlertAction(title: _l("Отменить"), style: .Cancel, handler: nil))
            rewriteDialog.addAction(UIAlertAction(title: _l("Перезаписать"), style: .Default)
            {
                [weak self] _ in
                if let emulator = (UIApplication.sharedApplication().delegate as! AppDelegate).mainViewController!.emulator
                {
                    self!.saveFile(self!.fileNames[indexPath.row],
                        description: self!.fileData[self!.fileNames[indexPath.row]]!.description,
                        memoryDump: emulator.dump())
                    self!.dismissViewControllerAnimated(true, completion: nil)
                }
            })
            presentViewController(rewriteDialog, animated: true, completion: nil)
        }
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool
        { return true }
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
        { return count(fileNames) }
    
    func setFileManagerMode(#isSaveMode: Bool)
    {
        self.isSaveMode = isSaveMode
        title = isSaveMode ? _l("Сохранить") : _l("Загрузить")
        
        if isSaveMode
        {
            if navigationItem.rightBarButtonItem == nil
            {
                navigationItem.rightBarButtonItem = UIBarButtonItem(
                    barButtonSystemItem: .Add, target: self, action: "newFile")
            }
        }
        else { navigationItem.rightBarButtonItem = nil }
    }

    private func reloadFileList()
    {
        // Получаем список файлов, проведя поиск по расширению и вырезав его.
        // Фильтрация выполняется средствами функционального программирования языка Swift,
        // так как слой совместимости с Objective-C и соответствующие функции вроде
        // pathsMatchingExtensions работают не во всех бета-версиях Xcode (не работают
        // в Beta 7, например).
        
        fileNames = (NSFileManager.defaultManager().subpathsOfDirectoryAtPath(
            documentDirectory, error: nil) as! [String])
            .filter { $0.lowercaseString.hasSuffix(self.dumpFileExtension) }
            .map { $0.substringToIndex(advance($0.startIndex,
                count($0) - count(self.dumpFileExtension))) }
        
        fileNames.sort(<)
        
        // Загружаем данные из файлов.
        for fileName in fileNames
        {
            if let data = loadFile(fileName) { fileData[fileName] = data }
            else { fileNames.removeAtIndex(find(fileNames, fileName)!) }
        }
    }

    func newFile()
    {
        if let emulator = (UIApplication.sharedApplication().delegate as! AppDelegate).mainViewController!.emulator
        {
            // TODO: Заменить на модальный контроллер
            // TODO: Добавить проверку на существующий файл
            
            let memoryDump = emulator.dump()
            var fields: (fileName: UITextField!, description: UITextField!)
            
            let saveDialog = UIAlertController(
                title: _l("Сохранить"), message: nil, preferredStyle: .Alert)
            
            saveDialog.addAction(UIAlertAction(
                title: _l("Отменить"), style: .Cancel, handler: nil))
            saveDialog.addAction(UIAlertAction(title: "OK", style: .Default)
            {
                [weak self] _ in
                self!.saveFile(fields.fileName.text,
                    description: fields.description.text, memoryDump: memoryDump)
                self!.dismissViewControllerAnimated(true, completion: nil)
            })
        
            saveDialog.addTextFieldWithConfigurationHandler
                { fields.fileName = $0; $0.placeholder = _l("имя файла") }
            saveDialog.addTextFieldWithConfigurationHandler
                { fields.description = $0; $0.placeholder = _l("описание") }
            
            presentViewController(saveDialog, animated: true, completion: nil)
        }
    }
    
    private func saveFile(fileName: String, description: String?, memoryDump: [UInt8])
    {
        /*
            Устаревший, а точнее отброшенный из-за сложностей реализации XML-вариант приведен ниже.
            Оставил на случай, если JSON вдруг будет реализовать еще тяжелее.
        
            let rootNode = XMLNode("SaveData")
            rootNode.addAttribute(name: "Name", value: "\(fileName)")
        
            let descriptionNode = XMLNode("Description")
            descriptionNode.innerXML = description
            rootNode.addChildNode(descriptionNode)
        
            // Дамп памяти будет закодирован в Base64, так как файл сохранения является XML-файлом,
            // а, следовательно, по возможности должен содержать только символы текстового диапазона.
            let memoryDumpNode = XMLNode("MemoryDump")
            memoryDumpNode.innerXML = NSData(bytes: memoryDump, length: countElements(memoryDump))
                .base64EncodedStringWithOptions(.Encoding64CharacterLineLength)
            rootNode.addChildNode(memoryDumpNode)
        */
        
        // Дамп памяти будет закодирован в Base64, так как файл сохранения является
        // JSON-файлом и не должен содержать символы управления.
        let base64MemoryDump = NSData(bytes: memoryDump,
            length: count(memoryDump)).base64EncodedStringWithOptions(.allZeros)
        
        // Создание словаря с данными и запись в файл.
        var saveData = ["memory_dump": base64MemoryDump]
        if description != nil && description != "" { saveData["description"] = description }
        
        let jsonData = NSJSONSerialization.dataWithJSONObject(saveData, options: .allZeros, error: nil)
        jsonData!.writeToFile(documentDirectory.stringByAppendingPathComponent(
            fileName + dumpFileExtension), atomically: true)
    }

    private func loadFile(fileName: String) -> (description: String?, memoryDump: [UInt8])?
    {
        let rawData = NSData(contentsOfFile: documentDirectory.stringByAppendingPathComponent(
            fileName + dumpFileExtension))
        
        var jsonError: NSError?
        let jsonObject = NSJSONSerialization.JSONObjectWithData(rawData!,
            options: nil, error: &jsonError) as? [String: String]
        
        if jsonError == nil || jsonObject != nil
        {
            if let memDump = jsonObject!["memory_dump"]
            {
                let decodedDump = NSData(base64EncodedString: memDump, options: .allZeros);
                
                // Весьма грязный unsafe-хак, но это же бета, поэтому можно.
                var dumpArray = [UInt8](count: decodedDump!.length, repeatedValue: 0x00)
                decodedDump!.getBytes(&dumpArray, length: decodedDump!.length)
                
                return (description: jsonObject!["description"], memoryDump: dumpArray)
            }
        }
        
        return nil
    }
    
    // Закрытие вида
    @IBAction func closeView()
    {
        dismissViewControllerAnimated(true, completion: nil)
    }
}