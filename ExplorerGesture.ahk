#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon
InstallMouseHook()
A_IconTip := "ExplorerGesture - 资源管理器右键手势"

global g_RButtonDown := false
global g_SendingClick := false
global g_LastChildDir := Map()

OnExit((*) => TrailOverlay.Shutdown())

#HotIf IsMouseOverExplorer()
RButton:: {
    global g_RButtonDown := true
    global g_SendingClick
    global g_LastChildDir
    Critical("Off")
    CoordMode("Mouse", "Screen")
    MouseGetPos(&startX, &startY, &hoverWin)
    scale := A_ScreenDPI / 96.0
    clickLimit := 20 * scale
    swipeMin := 50 * scale
    anchorStep := 10 * scale
    drawStep := 2 * scale
    backtrackLimit := 18 * scale
    startTime := A_TickCount
    isGesture := false

    pts := [[startX, startY]]
    lastAnchorX := startX, lastAnchorY := startY
    lastDrawX := startX, lastDrawY := startY
    prevX := startX, prevY := startY
    totalLen := 0.0
    boxMinX := startX, boxMaxX := startX
    boxMinY := startY, boxMaxY := startY
    isMessy := false
    endX := startX, endY := startY

    try {
        while g_RButtonDown {
            MouseGetPos(&curX, &curY)
            stepDist := CalcDist(curX - prevX, curY - prevY)
            if (stepDist >= drawStep) {
                totalLen += stepDist
                prevX := curX, prevY := curY
                if (curX < boxMinX)
                    boxMinX := curX
                if (curX > boxMaxX)
                    boxMaxX := curX
                if (curY < boxMinY)
                    boxMinY := curY
                if (curY > boxMaxY)
                    boxMaxY := curY
            }
            if (CalcDist(curX - lastAnchorX, curY - lastAnchorY) >= anchorStep) {
                pts.Push([curX, curY])
                lastAnchorX := curX, lastAnchorY := curY
            }
            if (CalcDist(curX - startX, curY - startY) > clickLimit) {
                isGesture := true
                break
            }
            if (A_TickCount - startTime >= 280) {
                Critical("On")
                if !g_RButtonDown {
                    Critical("Off")
                    break
                }
                g_RButtonDown := false
                Critical("Off")
                SendSafeRightClick("Down Right")
                return
            }
            Sleep(10)
        }

        if (!isGesture) {
            g_RButtonDown := false
            SendSafeRightClick("Right")
            return
        }

        isMessy := CheckMessy(startX, startY, curX, curY, totalLen, boxMinX, boxMaxX, boxMinY, boxMaxY, scale, backtrackLimit)
        TrailOverlay.Begin(pts, curX, curY, scale, isMessy)
        lastDrawX := curX, lastDrawY := curY

        waitStart := A_TickCount
        while (g_RButtonDown && A_TickCount - waitStart < 5000) {
            MouseGetPos(&curX, &curY)
            stepDist := CalcDist(curX - prevX, curY - prevY)
            if (stepDist >= drawStep) {
                totalLen += stepDist
                prevX := curX, prevY := curY
                if (curX < boxMinX)
                    boxMinX := curX
                if (curX > boxMaxX)
                    boxMaxX := curX
                if (curY < boxMinY)
                    boxMinY := curY
                if (curY > boxMaxY)
                    boxMaxY := curY
            }
            if (CalcDist(curX - lastAnchorX, curY - lastAnchorY) >= anchorStep) {
                pts.Push([curX, curY])
                lastAnchorX := curX, lastAnchorY := curY
            }
            if (CalcDist(curX - lastDrawX, curY - lastDrawY) >= drawStep) {
                if !isMessy {
                    isMessy := CheckMessy(startX, startY, curX, curY, totalLen, boxMinX, boxMaxX, boxMinY, boxMaxY, scale, backtrackLimit)
                }
                TrailOverlay.Render(pts, curX, curY, scale, isMessy)
                lastDrawX := curX, lastDrawY := curY
            }
            Sleep(10)
        }

        MouseGetPos(&endX, &endY)
        stepDist := CalcDist(endX - prevX, endY - prevY)
        totalLen += stepDist
        if (endX < boxMinX)
            boxMinX := endX
        if (endX > boxMaxX)
            boxMaxX := endX
        if (endY < boxMinY)
            boxMinY := endY
        if (endY > boxMaxY)
            boxMaxY := endY
        if !isMessy {
            isMessy := CheckMessy(startX, startY, endX, endY, totalLen, boxMinX, boxMaxX, boxMinY, boxMaxY, scale, backtrackLimit)
        }
        TrailOverlay.Render(pts, endX, endY, scale, isMessy)
    } finally {
        if isGesture
            TrailOverlay.HideDeferred()
        else
            TrailOverlay.HideNow()
    }

    g_RButtonDown := false
    dx := endX - startX
    dy := endY - startY
    netDist := CalcDist(dx, dy)

    ; 距离过短，或轨迹杂乱、折返、弯曲度过大则直接判定无效
    if (netDist < swipeMin || isMessy)
        return

    isHorizontal := (Abs(dx) > Abs(dy) * 1.73) && ((boxMaxY - boxMinY) <= Abs(dx) * 0.40)
    isVertical := (Abs(dy) > Abs(dx) * 1.73) && ((boxMaxX - boxMinX) <= Abs(dy) * 0.40)

    if (!isHorizontal && !isVertical)
        return

    if !WinExist(hoverWin)
        return

    if !WinActive(hoverWin) {
        try WinActivate(hoverWin)
        if !WinWaitActive(hoverWin, , 0.3)
            return
    }

    SetKeyDelay(20, 20)
    if isHorizontal {
        if (dx < 0) {
            ; 左滑：返回上一级（同时记住当前子目录以便右滑进入下一级）
            RememberCurrentFolder(hoverWin)
            SendEvent("!{Up}")
        } else {
            ; 右滑：进入下一级
            NavigateNextLevel(hoverWin)
        }
    } else if isVertical {
        tabKey := GetExplorerTabKey(hoverWin, &tab)
        if (dy < 0) {
            ; 上滑：历史记录回退（上一个）
            if tab {
                RememberTabFolder(tabKey, tab)
                try tab.GoBack()
            } else {
                SendEvent("!{Left}")
            }
        } else {
            ; 下滑：历史记录下一个（前进）
            if tab {
                try tab.GoForward()
            } else {
                SendEvent("!{Right}")
            }
        }
    }
}
#HotIf

#HotIf g_RButtonDown
*RButton Up:: {
    global g_RButtonDown := false
}
#HotIf

SendSafeRightClick(params) {
    global g_SendingClick := true
    try {
        Click(params)
    } finally {
        g_SendingClick := false
    }
}

RememberCurrentFolder(hoverWin) {
    tabKey := GetExplorerTabKey(hoverWin, &tab)
    if tab
        RememberTabFolder(tabKey, tab)
}

RememberTabFolder(tabKey, tab) {
    global g_LastChildDir
    try {
        curPath := tab.Document.Folder.Self.Path
        if (curPath != "") {
            if (g_LastChildDir.Count > 128)
                g_LastChildDir.Clear()
            g_LastChildDir[tabKey] := curPath
        }
    }
}

CheckMessy(sx, sy, cx, cy, totalLen, minX, maxX, minY, maxY, scale, backtrackLimit) {
    netDist := CalcDist(cx - sx, cy - sy)
    if (totalLen > netDist * 1.28 && (totalLen - netDist) > 12 * scale)
        return true
    if (maxX - sx > backtrackLimit && maxX - cx > backtrackLimit)
        return true
    if (sx - minX > backtrackLimit && cx - minX > backtrackLimit)
        return true
    if (maxY - sy > backtrackLimit && maxY - cy > backtrackLimit)
        return true
    if (sy - minY > backtrackLimit && cy - minY > backtrackLimit)
        return true
    return false
}

NavigateNextLevel(hoverWin) {
    global g_LastChildDir
    tabKey := GetExplorerTabKey(hoverWin, &tab)
    if !tab
        return

    ; 1. 若当前明确单选了一个文件夹，直接进入该下一级子文件夹
    try {
        sel := tab.Document.SelectedItems()
        if (sel && sel.Count == 1) {
            item := sel.Item(0)
            if (item.IsFolder && (DirExist(item.Path) || !FileExist(item.Path))) {
                tab.Navigate(item.Path)
                return
            }
        }
    }

    ; 2. 若刚从下一级子目录退回到当前父目录（含磁盘根目录退回“此电脑”），重新进入该下一级子目录
    try {
        rawCurPath := tab.Document.Folder.Self.Path
        curPath := RTrim(rawCurPath, "\")
        if (curPath != "" && g_LastChildDir.Has(tabKey)) {
            childPath := g_LastChildDir[tabKey]
            trimmedChild := RTrim(childPath, "\")
            if (curPath = "::{20D04FE0-3AEA-1069-A2D8-08002B30309D}" && (trimmedChild ~= "i)^[A-Z]:$") && DirExist(trimmedChild "\")) {
                tab.Navigate(trimmedChild "\")
                return
            }
            SplitPath(trimmedChild, , &parentOfChild)
            if (StrLower(RTrim(parentOfChild, "\")) == StrLower(curPath) && DirExist(childPath)) {
                tab.Navigate(childPath)
                return
            }
        }
    }
}

class TrailOverlay {
    static gui := 0, hideFn := 0, hMemDC := 0, hBM := 0, hOldBM := 0, pGraphics := 0
    static pPen := 0, pPenInvalid := 0, pCap := 0
    static vx := 0, vy := 0, vw := 0, vh := 0, lastScale := 0, token := 0
    static hasDirty := false, dirtyX := 0, dirtyY := 0, dirtyW := 0, dirtyH := 0
    static ptWin := Buffer(8, 0), szWin := Buffer(8, 0), ptSrc := Buffer(8, 0), blend := Buffer(4, 0)

    static EnsureCanvas(scale) {
        if !this.token {
            DllCall("LoadLibrary", "Str", "gdiplus")
            si := Buffer(24, 0)
            NumPut("UInt", 1, si, 0)
            DllCall("gdiplus\GdiplusStartup", "UPtr*", &tok := 0, "Ptr", si, "Ptr", 0)
            this.token := tok
            NumPut("UChar", 0, "UChar", 0, "UChar", 255, "UChar", 1, this.blend, 0)
        }
        if !this.gui {
            this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x80000 +E0x20 +E0x08000000")
            hwnd := this.gui.Hwnd
            this.hideFn := (*) => DllCall("ShowWindow", "Ptr", hwnd, "Int", 0)
        }

        vx := SysGet(76), vy := SysGet(77), vw := SysGet(78), vh := SysGet(79)
        if (vw <= 0 || vh <= 0) {
            vx := 0, vy := 0, vw := A_ScreenWidth, vh := A_ScreenHeight
        }

        if (!this.hMemDC || vw != this.vw || vh != this.vh || scale != this.lastScale) {
            this.ReleaseCanvas()
            this.vx := vx, this.vy := vy, this.vw := vw, this.vh := vh, this.lastScale := scale
            NumPut("Int", vx, "Int", vy, this.ptWin, 0)
            NumPut("Int", vw, "Int", vh, this.szWin, 0)

            bi := Buffer(40, 0)
            NumPut("UInt", 40, "Int", vw, "Int", -vh, "UShort", 1, "UShort", 32, bi, 0)
            hScreenDC := DllCall("GetDC", "Ptr", 0, "Ptr")
            this.hMemDC := DllCall("CreateCompatibleDC", "Ptr", hScreenDC, "Ptr")
            this.hBM := DllCall("CreateDIBSection", "Ptr", this.hMemDC, "Ptr", bi, "UInt", 0, "Ptr*", &pvBits := 0, "Ptr", 0, "UInt", 0, "Ptr")
            DllCall("ReleaseDC", "Ptr", 0, "Ptr", hScreenDC)
            this.hOldBM := DllCall("SelectObject", "Ptr", this.hMemDC, "Ptr", this.hBM, "Ptr")

            DllCall("gdiplus\GdipCreateFromHDC", "Ptr", this.hMemDC, "Ptr*", &pg := 0)
            this.pGraphics := pg
            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", this.pGraphics, "Int", 4)

            DllCall("gdiplus\GdipCreateAdjustableArrowCap", "Float", 3.8, "Float", 3.4, "Int", 1, "Ptr*", &pc := 0)
            this.pCap := pc
            DllCall("gdiplus\GdipSetAdjustableArrowCapMiddleInset", "Ptr", this.pCap, "Float", 0.35)

            DllCall("gdiplus\GdipCreatePen1", "UInt", 0xEC0078D4, "Float", 5.0 * scale, "Int", 2, "Ptr*", &pp := 0)
            this.pPen := pp
            DllCall("gdiplus\GdipSetPenStartCap", "Ptr", this.pPen, "Int", 2)
            DllCall("gdiplus\GdipSetPenLineJoin", "Ptr", this.pPen, "Int", 2)
            DllCall("gdiplus\GdipSetPenCustomEndCap", "Ptr", this.pPen, "Ptr", this.pCap)

            DllCall("gdiplus\GdipCreatePen1", "UInt", 0xAA808080, "Float", 5.0 * scale, "Int", 2, "Ptr*", &ppi := 0)
            this.pPenInvalid := ppi
            DllCall("gdiplus\GdipSetPenStartCap", "Ptr", this.pPenInvalid, "Int", 2)
            DllCall("gdiplus\GdipSetPenLineJoin", "Ptr", this.pPenInvalid, "Int", 2)
            DllCall("gdiplus\GdipSetPenCustomEndCap", "Ptr", this.pPenInvalid, "Ptr", this.pCap)

            this.hasDirty := false
        } else {
            this.vx := vx, this.vy := vy
            NumPut("Int", vx, "Int", vy, this.ptWin, 0)
            DllCall("gdiplus\GdipResetClip", "Ptr", this.pGraphics)
            DllCall("gdiplus\GdipGraphicsClear", "Ptr", this.pGraphics, "UInt", 0)
            this.hasDirty := false
        }
    }

    static Begin(pts, curX, curY, scale, isMessy := false) {
        if this.hideFn
            SetTimer(this.hideFn, 0)
        this.EnsureCanvas(scale)
        this.Render(pts, curX, curY, scale, isMessy)
        DllCall("ShowWindow", "Ptr", this.gui.Hwnd, "Int", 8)
        DllCall("SetWindowPos", "Ptr", this.gui.Hwnd, "Ptr", -1
            , "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
    }

    static Render(pts, curX, curY, scale, isMessy := false) {
        if !this.pGraphics
            return

        if (this.hasDirty && this.dirtyW > 0 && this.dirtyH > 0) {
            DllCall("gdiplus\GdipSetClipRectI", "Ptr", this.pGraphics
                , "Int", this.dirtyX, "Int", this.dirtyY
                , "Int", this.dirtyW, "Int", this.dirtyH, "Int", 0)
            DllCall("gdiplus\GdipGraphicsClear", "Ptr", this.pGraphics, "UInt", 0)
            DllCall("gdiplus\GdipResetClip", "Ptr", this.pGraphics)
        }

        n := pts.Length
        lastPt := pts[n]
        replaceLast := (n >= 2 && CalcDist(curX - lastPt[1], curY - lastPt[2]) < 6 * scale)
        count := replaceLast ? n : (n + 1)
        copyCount := replaceLast ? (n - 1) : n

        ptBuf := Buffer(count * 8)
        minX := 999999, minY := 999999, maxX := -999999, maxY := -999999

        Loop copyCount {
            px := pts[A_Index][1] - this.vx
            py := pts[A_Index][2] - this.vy
            NumPut("Float", px, "Float", py, ptBuf, (A_Index - 1) * 8)
            if (px < minX)
                minX := px
            if (py < minY)
                minY := py
            if (px > maxX)
                maxX := px
            if (py > maxY)
                maxY := py
        }

        tx := curX - this.vx
        ty := curY - this.vy
        NumPut("Float", tx, "Float", ty, ptBuf, (count - 1) * 8)
        if (tx < minX)
            minX := tx
        if (ty < minY)
            minY := ty
        if (tx > maxX)
            maxX := tx
        if (ty > maxY)
            maxY := ty

        pen := isMessy ? this.pPenInvalid : this.pPen
        if (count >= 3) {
            DllCall("gdiplus\GdipDrawCurve2", "Ptr", this.pGraphics, "Ptr", pen
                , "Ptr", ptBuf, "Int", count, "Float", 0.35)
        } else if (count == 2) {
            DllCall("gdiplus\GdipDrawLines", "Ptr", this.pGraphics, "Ptr", pen
                , "Ptr", ptBuf, "Int", 2)
        }

        pad := Ceil(32 * scale)
        x1 := Max(0, Floor(minX) - pad)
        y1 := Max(0, Floor(minY) - pad)
        x2 := Min(this.vw, Ceil(maxX) + pad)
        y2 := Min(this.vh, Ceil(maxY) + pad)
        this.dirtyX := x1, this.dirtyY := y1
        this.dirtyW := Max(0, x2 - x1), this.dirtyH := Max(0, y2 - y1)
        this.hasDirty := true

        DllCall("UpdateLayeredWindow", "Ptr", this.gui.Hwnd, "Ptr", 0
            , "Ptr", this.ptWin, "Ptr", this.szWin
            , "Ptr", this.hMemDC, "Ptr", this.ptSrc
            , "UInt", 0, "Ptr", this.blend, "UInt", 2)
    }

    static HideDeferred() {
        if this.hideFn
            SetTimer(this.hideFn, -150)
    }

    static HideNow() {
        if this.gui
            DllCall("ShowWindow", "Ptr", this.gui.Hwnd, "Int", 0)
    }

    static ReleaseCanvas() {
        if this.pPen {
            DllCall("gdiplus\GdipDeletePen", "Ptr", this.pPen)
            this.pPen := 0
        }
        if this.pPenInvalid {
            DllCall("gdiplus\GdipDeletePen", "Ptr", this.pPenInvalid)
            this.pPenInvalid := 0
        }
        if this.pCap {
            DllCall("gdiplus\GdipDeleteCustomLineCap", "Ptr", this.pCap)
            this.pCap := 0
        }
        if this.pGraphics {
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", this.pGraphics)
            this.pGraphics := 0
        }
        if this.hMemDC {
            if this.hOldBM
                DllCall("SelectObject", "Ptr", this.hMemDC, "Ptr", this.hOldBM)
            if this.hBM
                DllCall("DeleteObject", "Ptr", this.hBM)
            DllCall("DeleteDC", "Ptr", this.hMemDC)
            this.hMemDC := 0, this.hBM := 0, this.hOldBM := 0
        }
    }

    static Shutdown() {
        if this.hideFn
            SetTimer(this.hideFn, 0)
        this.ReleaseCanvas()
        if this.gui {
            try this.gui.Destroy()
            this.gui := 0
        }
        if this.token {
            DllCall("gdiplus\GdiplusShutdown", "UPtr", this.token)
            this.token := 0
        }
    }
}

IsMouseOverExplorer() {
    global g_SendingClick
    if g_SendingClick
        return false
    MouseGetPos(&mx, &my, &hoverWin, &hoverCtrl)
    try {
        if (WinGetClass(hoverWin) != "CabinetWClass")
            return false
        ; 在重命名文件或传统地址栏文本编辑框内右键时放行原生文本菜单
        if (hoverCtrl ~= "i)^Edit\d*$")
            return false
        return true
    }
    return false
}

GetExplorerTabKey(hwnd, &outTab) {
    outTab := 0
    activeTab := 0
    try activeTab := ControlGetHwnd("ShellTabWindowClass1", hwnd)
    try {
        for w in ComObject("Shell.Application").Windows {
            try {
                if (w.hwnd != hwnd)
                    continue
                if activeTab {
                    static IID_IShellBrowser := "{000214E2-0000-0000-C000-000000000046}"
                    sb := ComObjQuery(w, IID_IShellBrowser, IID_IShellBrowser)
                    ComCall(3, sb, "uint*", &thisTab := 0)
                    if (thisTab != activeTab)
                        continue
                }
                outTab := w
                return activeTab ? activeTab : hwnd
            }
        }
    }
    return activeTab ? activeTab : hwnd
}

CalcDist(dx, dy) {
    return Sqrt(dx * dx + dy * dy)
}
