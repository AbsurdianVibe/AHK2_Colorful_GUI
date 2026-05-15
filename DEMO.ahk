#Requires AutoHotkey v2.0
#Include AHK2ColorfulGUI.ahk

; Set dark theme base color, or any color you want!
SilnikGUI.Konfiguruj("2B2B2B")
SilnikGUI.FontManagment("Segoe UI", 10)

; Main app window
App := SilnikGUI("AHK2 Colorful GUI - Feature Demo", "+MinSize200x200", {
    MainGUI: true,
    CSBarV: 1, 
    CSBarH: 1, 
    GruboscRamki: 2, 
    ResizeMarg: 8,
    PadD: 20
})

; --- Header ---
App.Add("Text", "X10 w630 h30 Center BackgroundFFFFFF", "Welcome to AHK2ColorfulGUI Demo").SetFont("s16 bold")

; --- Inputs ---
App.Add("Text", "xm y+15 w600 cAAAAAA", "--- Input Fields ---").SetFont("s12 italic")

; String Validation (Type 2)
App.DodajWierszKonfiguracji("Username:", "Guest User", {
    trybWalidacji: 2, 
    SzerPola: 200,
    pozycja: "xm"
})

; Integer Validation (Type 0) with limits and scroll step
App.DodajWierszKonfiguracji("Volume (Int):", 50, {
    trybWalidacji: 0, 
    minVal: 0, 
    maxVal: 100, 
    skok: 5,
    SzerPola: 100
})

; Float Validation (Type 1) with limits
App.DodajWierszKonfiguracji("Speed (Float):", 1.25, {
    trybWalidacji: 1, 
    minVal: 0.1, 
    maxVal: 5.0, 
    skok: 0.1,
    SzerPola: 100
})

; Multiline (Type 3)
App.DodajWierszKonfiguracji("Description:", "Line 1: AHK is great!`nLine 2: ColorfulGUI is awesome!", {
    trybWalidacji: 3, 
    WysInput: 3, 
    SzerPola: 250
})

; --- Toggles and Selectors ---
App.Add("Text", "xm y+20 w600 cAAAAAA", "--- Controls ---").SetFont("s12 italic")

; Checkbox
chk := App.DodajCheckbox("Enable Advanced Mode", {czyZaznaczony: true, InfoRight: 1})
chk.OnEvent("Click", (ctrl, *) => SilnikGUI.CustomTooltip(ctrl.Value ? "Enabled!" : "Disabled!", {czas: 2000, trybPozycji: "Mouse"}))

; DropDown List
App.DodajDDList(["First Option", "Second Option", "Third Option", "Fourth Option"], 
    (ctrl, idx) => SilnikGUI.CustomTooltip("Selected: " ctrl.Opcje[idx], {czas: 2000, trybPozycji: "Mouse"}), 
    2, 200, "xm"
)

; --- Interactive Buttons ---
App.Add("Text", "xm y+20 w600 cAAAAAA", "--- Dialogs & Tooltips ---").SetFont("s12 italic")

; Custom Error Dialog
App.DodajPrzycisk("Show Error Dialog", (ctrl, *) => (
    SilnikGUI.OknoBledu("Critical Failure", "This is a demonstration of the custom error dialog.", "Please contact support or try again.", App.GuiObj.Hwnd)
), "xm w150 h30")

; Custom Tooltip
App.DodajPrzycisk("Show Tooltip", (ctrl, *) => (
    SilnikGUI.CustomTooltip("This is a stylized tooltip!`nIt follows the mouse and supports`nmultiple lines.`n.[3].`n...And separators!", {czas: 3000, czyPogrubione: 1})
), "x+10 yp w150 h30")

; Auto-expanding dialog demo
App.DodajPrzycisk("Dynamic Window", (ctrl, *) => (
    SilnikGUI.CustomTooltip("This window will auto-expand when typing long text.", {czas: 3000, trybPozycji: "Mouse"}),
    ShowDynamicDialog()
), "x+10 yp w150 h30")

; Tab tracking demo
App.DodajPrzycisk("Tab tracking demo", (ctrl, *) => ShowTabTrackingDemo(), "x+10 yp w150 h30")

; --- Panels ---
App.Add("Text", "xm y+20 w600 cAAAAAA", "--- Panels & Scrolling ---").SetFont("s12 italic")

; Nested Scrollable Sub-Panel
SubPanel := App.DodajPanel(2, 1, 1, {PadD: 10})
SubPanel.Add("Text", "xm", "I am a nested panel!")
Loop 5
    SubPanel.DodajCheckbox("Sub-item " A_Index, {pozycja: "xm"})
SubPanel.PokazPanel(App, "x10 y+10", "w250 h100")

; Scrollable Text Panel
LongText := "This is line 1 inside the text panel........`nThis is line 2.`nKeep scrolling down...`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nEnd of text."
TxtPanel := App.DodajPanelTxt(LongText, 250, 120, {InfiniteLine:1, pozycja: "x+20 yp"})
TxtPanel.Stan.VBar.Thumb.HoverAction := (*) => SilnikGUI.CustomTooltip("Hold CTRL while dragging`nto feel TRUE PRECISION!", {czas: 2000,trybPozycji: "Mouse", czyPogrubione: 1})
TxtPanel.Stan.HBar.Thumb.HoverAction := (*) => SilnikGUI.CustomTooltip("Try scrolling with the mouse wheel over my", {czas: 2000,trybPozycji: "Mouse", czyPogrubione: 1})

/**
 * @desc Dynamiczne okno demonstracyjne (klon mechaniki okna zmiany nazwy F2).
 */
ShowDynamicDialog() {
    static Z := 0
    if (Z && WinExist(Z.GuiObj.Hwnd))
        return Z.Pokaz()

    ; Inicjalizacja bez paska tytułowego, dopasowująca szerokość (AutoFitW: 0.99)
    Z := SilnikGUI("DYNAMIC RENAME", "MinSize300x0", {unikalny: 1, pokazPasek: 0, createChild: true, zamknijNaEsc: 1, CSBarV: 0, CSBarH: 0, ResizeMarg: 0, GruboscRamki: 2, PadR: 20, PadD: 15, AutoFitW: 0.99})
    if (!Z.nowaInstancja)
        return Z.Pokaz()
    
    Z.GuiObj.OnEvent("Close", (*) => Z := 0)
    Z.GuiObj.SetFont("s10")
    
    closeAction := (*) => (Z.Zakoncz(), Z := 0)
    Z.DodajWierszKonfiguracji("New name:", "Type a very long text here...", {trybWalidacji: 2, pozycja: "x20 yp+15", SzerPola: 100, AutoCenter: true, SzRamki: 2, ResizeEditW: true, obslugaEnter: closeAction})
    
    btnZapisz := Z.DodajPrzycisk("Save", closeAction, "xm y+20 w100 h30")
    btnAnuluj := Z.DodajPrzycisk("Cancel", closeAction, "yp w100 h30")
    
    Z.CallbackLayout := (Szer, Off := 0, *) => (gap := (Szer - 200) / 3, btnZapisz.Move(gap + Off), btnAnuluj.Move(Szer - gap - 100 + Off))
    Z.Pokaz()
}

/**
 * @desc Demo śledzenia fokusu (Tab) z szeroko rozrzuconymi kontrolkami.
 */
ShowTabTrackingDemo() {
    static T := 0
    if (T && WinExist(T.GuiObj.Hwnd))
        return T.Pokaz()

    T := SilnikGUI("Tab Tracking Demo", "MinSize200x200", {unikalny: "TabDemo", pokazPasek: 1, createChild: true, zamknijNaEsc: 1, CSBarV: 1, CSBarH: 1, PadD: 30, PadR: 30})
    if (!T.nowaInstancja)
        return T.Pokaz()
    
    T.GuiObj.OnEvent("Close", (*) => (T.Zakoncz(), T := 0))
    
    T.DodajWierszKonfiguracji("Step 1:", "Press TAB...", {pozycja: "x20 y20", SzerPola: 120})
    T.DodajCheckbox("Step 2 (Far Right)", {pozycja: "x600 y150"})
    T.DodajDDList(["Step 3.A", "Step 3.B"], 0, 1, 150, "x50 y500")
    T.DodajPrzycisk("Step 4 (Far Bottom)", (*) => SilnikGUI.CustomTooltip("Done!", {czas: 2000, trybPozycji: "Mouse"}), "x500 y800 w150 h30")
    
    T.Pokaz("w300 h300")
}

; Render main window
App.Pokaz("y20 w650 h700")