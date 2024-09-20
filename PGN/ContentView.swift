//
//  ContentView.swift
//  PGN
//
//  Created by Kai on 2023/4/13.
//

import SwiftUI
import UniformTypeIdentifiers

fileprivate let attrDict = [
    "白方": "White",
    "白方等级分": "WhiteElo",
    //"白方团队": "WhiteTeam",
    //"白方称号": "WhiteTitle",
    "黑方": "Black",
    "黑方等级分": "BlackElo",
    //"黑方团队": "BlackTeam",
    //"黑方称号": "BlackTitle",
    "比赛用时": "TimeControl",
    "日期": "Date",
    "结果": "Result",
    //"结束方式": "Termination",
    "轮次": "Round",
    "桌次": "Board",
    "比赛名称": "Event",
    "比赛地点": "Site",
    "标注者": "Annotator",
    "ECO": "ECO",
    "FEN": "FEN"
]

fileprivate let labelNames = [
    "白方",
    "白方等级分",
    //"白方团队",
    //"白方称号",
    "黑方",
    "黑方等级分",
    //"黑方团队",
    //"黑方称号",
    "比赛用时",
    "日期",
    "结果",
    //"结束方式",
    "轮次",
    "桌次",
    "比赛名称",
    "比赛地点",
    "标注者",
    "ECO",
    "FEN"
]

struct Attr: Hashable {
    let labelName: String
    let attrName: String
    var content: String
    
    init(labelName: String, attrName: String, content: String) {
        self.labelName = labelName
        self.attrName = attrName
        self.content = content
    }
    
    func toPGN() -> String {
        if self.content == "" {
            return ""
        }
        return "[\(self.attrName) \"\(self.content)\"]\n"
    }
    
    mutating func checkPGN(pgnContent pgn: inout String) -> Bool {
        if let range = pgn.range(of: self.attrName) {
            var sub = pgn.suffix(from: range.upperBound)
            sub.removeFirst()
            sub.removeFirst()
            if let end = sub.firstIndex(of: "\"") {
                let content = sub.prefix(upTo: end)
                if self.content == "" {
                    self.content = String(content)
                }
                return true
            }
        }
        return false
    }
}

struct AttrList: Hashable {
    static func == (lhs: AttrList, rhs: AttrList) -> Bool {
        return lhs.attrList == rhs.attrList
    }
    func hash(into hasher: inout Hasher) {
        for attr in attrList {
            hasher.combine(attr)
        }
    }
    
    var attrList: [Attr]
    init() {
        attrList = Array<Attr>()
        for labelName in labelNames {
            attrList.append(Attr(labelName: labelName, attrName: attrDict[labelName]!, content: ""))
        }
    }
    mutating func clear() -> Void {
        for i in 0..<attrList.count {
            attrList[i].content = ""
        }
    }
}

struct AttrView: View {
    @Binding var attr: Attr
    var body: some View {
        HStack {
            Text(attr.labelName)
                .frame(minWidth: 70, alignment: .trailing)
            TextField("", text: $attr.content)
                .border(Color.black)
                .frame(minWidth:200, maxWidth: 240)
        }
    }
}

struct AttrsView: View {
    @Binding var list: AttrList
    var body: some View {
        VStack {
            Text("属性").frame(alignment: .center)
            ForEach(0..<list.attrList.count-1, id: \.self) {
                AttrView(attr: $list.attrList[$0])
            }
            HStack {
                Text(list.attrList.last!.labelName).frame(minWidth: 70, alignment: .trailing)
                TextEditor(text: $list.attrList.last!.content)
                    .border(Color.black)
                    .frame(minWidth:200, maxWidth: 240, minHeight: 60, maxHeight: 90)
                    .font(Font.custom("Times New Roman", size: 14))
            }
        }
    }
}

struct RawPGNView: View {
    @Binding var rawPGN: String
    var body: some View {
        VStack {
            Text("原始的PGN文本")
                .frame(alignment: .center)
            TextEditor(text: $rawPGN)
                .border(Color.black)
                .font(Font.custom("Times New Roman", fixedSize: 16.5))
        }
        .frame(width: 400, height: 520)
    }
    static func extractInfo(attrList: inout AttrList, rawPGN: inout String) -> (String, Bool) {
        var pgnAttr = false
        var attrInfo = ""
        let dealing = { (attr: inout Attr, rawPGN: inout String) -> String in
            if attr.checkPGN(pgnContent: &rawPGN) {
                pgnAttr = true
            }
            return attr.toPGN()
        }
        for i in 0..<attrList.attrList.count {
            attrInfo.append(dealing(&attrList.attrList[i], &rawPGN))
        }

        return (attrInfo, pgnAttr)
    }
    static func extractContent(rawPGN: inout String, index: Int) -> (String, Bool) {
        var formatError = false
        /* PGN格式检验 */
        let rawSubStr = rawPGN.suffix(from: rawPGN.index(rawPGN.startIndex, offsetBy: index))
        if #available(macOS 13.0, *) {
            if rawSubStr.firstRange(of: "1.") == nil {
                formatError = true
                return ("", formatError)
            }
        } else {
            // Fallback on earlier versions
            if rawSubStr.range(of: "1.") == nil {
                formatError = true
                return ("", formatError)
            }
        }
        let subStr = rawSubStr.replacingOccurrences(of: "0-0-0", with: "O-O-O")
                              .replacingOccurrences(of: "0-0", with: "O-O")
        
        let cstring = subStr.cString(using: .utf8)!
        var charArray = Array<CChar>()
        
        let space: CChar = 32
        let plus: CChar = 43
        let equal: CChar = 61
        let O: CChar = 79 /* O not 0 */
        let minus: CChar = 45
        
        let isLower = { (char: CChar) -> Bool in return 97 <= char && char <= 122 }
        let isUpper = { (char: CChar) -> Bool in return 65 <= char && char <= 90 }
        let isNumber = { (char: CChar) -> Bool in return 48 <= char && char <= 57 }
        
        /* 格式化 */
        for i in 0..<cstring.count {
            charArray.append(cstring[i])
            if i == 0 || i == 1 || i == 2 || i == cstring.count-1 {
                continue
            }
            if cstring[i] == space {
                continue
            }
            if cstring[i+1] == equal || cstring[i+1] == plus {
                continue
            }
            if cstring[i-2] == O && cstring[i-1] == minus && cstring[i] == O {
                if cstring[i+1] == minus && cstring[i+2] == O {
                    continue
                }
                charArray.append(space)
                continue
            }
            if cstring[i] == plus ||
                (isLower(cstring[i-1]) && isNumber(cstring[i])) ||
                (cstring[i-1] == equal && isUpper(cstring[i])) {
                charArray.append(space)
            }
        }
        
        let content = String(cString: charArray)
        return (content, formatError)
    }
    static func extract(attrList: inout AttrList, rawPGN: inout String) -> (String, Bool) {
        var attrInfo = ""
        var pgnAttr = false
        (attrInfo, pgnAttr) = RawPGNView.extractInfo(attrList: &attrList, rawPGN: &rawPGN)
        var i = 0
        if pgnAttr {
            if #available(macOS 13.0, *) {
                let lastIndex = rawPGN.ranges(of: "\"]").last!.upperBound
                i = rawPGN.distance(from: rawPGN.startIndex, to: lastIndex)+1
            } else {
                // Fallback on earlier versions
                let lastIndex = rawPGN.range(of: "\"]", options: .backwards)!.upperBound
                i = rawPGN.distance(from: rawPGN.startIndex, to: lastIndex)+1
            }
        } else if attrInfo != "" {
            attrInfo.append("\n")
        }
        let (content, formatError) = RawPGNView.extractContent(rawPGN: &rawPGN, index: i)
        return (attrInfo + content, formatError)
    }
}

struct FormattedPGNView: View {
    @Binding var formattedPGN: String
    var body: some View {
        VStack {
            Text("格式化的PGN文本")
                .frame(alignment: .center)
            TextEditor(text: $formattedPGN)
                .border(Color.black)
                .font(Font.custom("Times New Roman", fixedSize: 16.5))
        }
        .frame(width: 400, height: 520)
    }
}

struct ContentView: View {
    @State private var rawPGN: String = ""
    @State private var formattedPGN: String = ""
    @State private var attrlist: AttrList = AttrList()
    @State private var emptyFile: Bool = false
    @State private var pgnFormatError: Bool = false
    @State private var pgnSaveError: Bool = false
    @State private var copySuccess: Bool = false
    @State private var copyFailure: Bool = false
    var body: some View {
        VStack {
            HStack {
                Spacer()
                AttrsView(list: $attrlist)
                Spacer()
                RawPGNView(rawPGN: $rawPGN)
                Spacer()
                FormattedPGNView(formattedPGN: $formattedPGN)
                Spacer()
            }
            HStack {
                Button("清除数据", action: self.clear)
                Button("格式化", action: self.format)
                    .alert("PGN格式有误", isPresented: $pgnFormatError, actions: { Text("") })
                Button("导出PGN文件", action: self.export)
                    .alert("导出错误：文本为空", isPresented: $emptyFile, actions: { Text("") })
                    .alert("导出错误：无法创建pgn文件", isPresented: $pgnSaveError, actions: { Text("") })
                Button("复制到剪切板", action: self.copyBoard)
                    .alert("复制成功", isPresented: Binding.constant(copySuccess), actions: { Text("") })
                    .alert("复制失败", isPresented: Binding.constant(copyFailure), actions: { Text("") })
            }
        }
    }
    func clear() -> Void {
        rawPGN = ""
        formattedPGN = ""
        attrlist.clear()
    }
    func setDefault() -> Void {
        self.emptyFile = false
        self.pgnFormatError = false
        self.pgnSaveError = false
        self.copySuccess = false
        self.copyFailure = false
    }
    func format() -> Void {
        self.setDefault()
        var formatted = ""
        (formatted, pgnFormatError) = RawPGNView.extract(attrList: &attrlist, rawPGN: &rawPGN)
        if !pgnFormatError {
            formattedPGN = formatted
        }
    }
    func export() -> Void {
        self.setDefault()
        if formattedPGN == "" {
            emptyFile = true
            return
        }
        
        let pgnData = formattedPGN.data(using: .utf8)!
        let savePanel = NSSavePanel()
        
        savePanel.begin(completionHandler: { (result) in
            if result == .OK {
                let url = savePanel.url
                let filePath = url?.appendingPathExtension("pgn")
                do {
                    try pgnData.write(to: filePath!)
                } catch {
                    pgnSaveError = true
                }
            }
        })
    }
    func copyBoard() -> Void {
        self.setDefault()
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        if pasteBoard.setString(formattedPGN, forType: .string) {
            self.copySuccess = true
        } else {
            self.copyFailure = true
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
