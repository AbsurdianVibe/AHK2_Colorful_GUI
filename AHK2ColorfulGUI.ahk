#Requires AutoHotkey v2.0

class ConfigGUI {
    static _TickRate := 15
    ; [TickRate=15] - Globalne taktowanie silnika (ms). Wartości <15 wymuszają wysoką rozdzielczość zegara (timeBeginPeriod).
    static TickRate {
        get => this._TickRate
        set {
            if (this._TickRate < 15)
                DllCall("winmm\timeEndPeriod", "UInt", this._TickRate)
            this._TickRate := value
            if (value < 15)
                DllCall("winmm\timeBeginPeriod", "UInt", value)
        }
    }
    ;[CSBarV=1] - Pionowy pasek przewijania (0/1), (silnik).
    static CSBarV := 1
    ;[CSBarH=1] - Poziomy pasek przewijania (0/1), (silnik).
    static CSBarH := 1
    ;[PokazPasek=1] - Pasek tytułowy okna (0/1), (silnik).
    static PokazPasek := 1
    ; [UseChild=true] - Tryb dwuwarstwowy GUI (Canvas/Viewport), (silnik).
    static UseChild := true
    ;[GruboscRamki=2] - Grubość ramek okna, (silnik).
    static GruboscRamki := 2
    ; [RamkaPanelu=2] - Wewnętrzny odstęp paneli. ;todo czy to powinno
    static RamkaPanelu := 2
    ; [PadL=0] - Margines z lewej strony, (silnik).
    static PadL := 0
    ;[PadR=0] - Margines z prawej strony, (silnik).
    static PadR := 0
    ; [PadD=0] - Margines od dołu.(sinik)
    static PadD := 0
    ; [AutoFitW=0] - Dopasowanie szerokości. [n>0-1] - % szerokości ekranu. [n>1] px. 0 = brak autofit.
    static AutoFitW := 0
    ; [AutoFitH=0] - Dopasowanie wysokości. [n>0-1] - % wysokości ekranu. [n>1] px. 0 = brak autofit.
    static AutoFitH := 0
    ; [zamknijNaEsc=1] - Zamykanie na Esc: [0]=Off, [1]=Hide, [2]=Destroy.
    static zamknijNaEsc := 1
    ; [ResizeMarg=6] - Strefa zmiany rozmiaru.
    static ResizeMarg := 6
    ; [dragBezPaska=1] - Przeciąganie okna bez paska tytułowego.
    static dragBezPaska := 1
    ; [TipDelayON=200] - Opóźnienie przed pojawieniem się CustomTooltipów (ms).
    Static TipDelayON := 200
    ; [TipDelayOFF=200] - Opóźnienie wygaszania CustomTooltipów (ms).
    Static TipDelayOFF := 200
    ;[CallbackLayout=0] - Własna funkcja klienta do dynamicznego pozycjonowania kontrolek (wywoływana przy każdym resize).
    ; - Sygnatura: (Szerokosc, OffsetX, Wysokosc, WysWiersza) => void.
    ; - Szerokosc - Czysta, dostępna przestrzeń robocza w poziomie (po odjęciu ramek, marginesów i ewentualnych pasków przewijania). Główny parametr do wyliczania Gap i szerokości kontrolek.
    ; - OffsetX - Wewnętrzne przesunięcie X (np. gdy używamy systemowego paska, a okno wymusza dodatkowy offset ramki). Zawsze dodawaj tę wartość do wyliczonego X.
    ; - Wysokosc - Opcjonalna dostępna przestrzeń robocza w pionie.
    ; - WysWiersza - Opcjonalna standardowa wysokość wiersza wynikająca z wybranej czcionki.
    ; - INSTRUKCJA: Wewnątrz przypisanej funkcji należy wykonywać wyłącznie matematykę oraz wywoływać metodę .Move(x, y, w, h) na własnych kontrolkach. Silnik sam zadba o debouncing (blokadę spamu wywołań) oraz odświeżenie GDI po wykonaniu callbacku.
    CallbackLayout := 0

}
class Data extends ConfigGUI {
    ; obiekt główny: SilnikGUI. Zawiera wszystkie funkcje, właściwości i klasy pomocnicze. Jest to jedyny obiekt, który jest bezpośrednio tworzony przez użytkownika (np. Appa := SilnikGUI(...)). Wszystkie inne klasy są zagnieżdżone wewnątrz SilnikGUI jako statyczne właściwości lub są tworzone jako instancje wewnątrz SilnikGUI.
    GuiObj := 0


    ; Obiekt stanu SilnikGUI, NIE MODYFIKOWAĆ!
    Stan := {
        ClipGui: 0,
        ChildGui: 0,
        FocusSink: 0,
        VBar: 0,
        HBar: 0,
        Corner: 0,
        Kontrolki: [],
        TimerFocus: 0,
        HandlerDrag: 0,
        CzyPokazano: false,
        PopupHwnd: 0,
        AktywnyTooltip: 0,
        ActiveScrollLoopCtrl: 0,
        Dzieci: [],
        PopupActive: false,
        DebounceRedraw: 0,
        MonState: { LastFocus: 0, LastHover: 0, LastRealFocus: 0, WasFlashing: false, LastInput: { x: 0, y: 0, win: 0, ctl: 0, foc: 0, act: 0, lbtn: 0 }, LastRenderLBtn: 0 },
        RootHwnd: 0,
        LastActiveState: -1,
        LastObszar: { W: 0, H: 0 },
        LastObszarTick: 0,
        LastLayoutState: 0,
        AktualnyKolorRamki: "",
        AktualnyKolorPrzycisku: "",
        AktualnyKolorTekstu: "",
        ScrollDelta: 0,
        CSBarV: SilnikGUI.CSBarV,
        CSBarH: SilnikGUI.CSBarH,
        PokazPasek: SilnikGUI.PokazPasek,
        UseChild: SilnikGUI.UseChild,
        GruboscRamki: SilnikGUI.GruboscRamki,
        RamkaPanelu: SilnikGUI.RamkaPanelu,
        PadL: SilnikGUI.PadL,
        PadR: SilnikGUI.PadR,
        PadD: SilnikGUI.PadD,
        AutoFitW: SilnikGUI.AutoFitW,
        AutoFitH: SilnikGUI.AutoFitH,
        zamknijNaEsc: SilnikGUI.zamknijNaEsc,
        ResizeMarg: SilnikGUI.ResizeMarg,
        dragBezPaska: SilnikGUI.dragBezPaska,
        MainGUI: false
    }

    /**
     * Głęboka konfiguracja mechaniki przewijania (Deep Merge).
     * PRZYKŁAD: SilnikGUI.KonfigurujScroll({MButton: {Czulosc: 0.08}, Kinetyka: {BarSize: 15}})
     * @property {Boolean} [MBCurScale=true] - Skalowanie wielkości kursora dla MButton (0/1).
     * @property {Integer} [stepXAr=20] - Skok X dla strzałek na klawiaturze.
     * @property {Integer} [stepXWh=50] - Skok X dla kółka myszy.
     * @property {Integer} [stepXBu=20] - Skok X dla przycisków paska.
     * @property {Integer} [stepYAr=10] - Skok Y dla strzałek na klawiaturze.
     * @property {Integer} [stepYWh=30] - Skok Y dla kółka myszy.
     * @property {Integer} [stepYBu=10] - Skok Y dla przycisków paska.
     * @property {Float} [AnimSoft=0.17] - Siła hamowania kinetyki (0-1).
     * @property {Float} [AccBu=1.01] - Mnożnik akceleracji dla przycisków paska.
     * @property {Float} [AccTlo=1.05] - Mnożnik akceleracji dla tła paska.
     * @property {Float} [AltFact=2] - Mnożnik pędu dla Alt.
     * @property {Float} [CtrlFact=0.5] - Mnożnik pędu dla Ctrl.
     * @property {Float} [MBuCz=0.05] - Mnożnik prędkości (domyślnie 0.05).
     * @property {Integer} [MBuDeadZone=15] - Martwa strefa w px.
     * @property {Integer} [MBuProgHam=200] - Tłumienie przy krawędzi w px.
     * @property {Integer} [MBuProgFakt=8] - Skalowanie tłumienia.
     * @property {Float} [MBuWyb=1.0] - Siła pędu resztkowego.
     * @property {Integer} [MBuToggleT=200] - Max czas kliknięcia dla trybu toggle (ms).
     * @property {Float} [MBuMaxSpeed=0.15] - Limit pędu oddawanego do paska.
     * @property {Integer} [ArMaxSpeed=100] - Limit kinetyki klawiatury na pasku.
     * @property {Float} [TloMaxSpeed=6] - Akceleracja tła paska.
     * @property {Integer} [MinThumbSize=20] - Min. rozmiar suwaka w px.
     * @property {Integer} [BarSize=20] - Grubość paska w px.
     * @property {Integer} [ArT=30] - Pompowanie strzałek (ms).
     */
    static ConfigScroll := {
        MBCurScale: true,
        stepXAr: 20, stepXWh: 50, stepXBu: 20,
        stepYAr: 10, stepYWh: 30, stepYBu: 10,
        AnimSoft: 0.17, AccBu: 1.01, AccTlo: 1.05,
        AltFact: 2, CtrlFact: 0.5,
        MBuCz: 0.05, MBuDeadZone: 15, MBuProgHam: 200, MBuProgFakt: 8, MBuWyb: 1.0, MBuToggleT: 200, MBuMaxSpeed: 0.15,
        ArMaxSpeed: 100, TloMaxSpeed: 6, MinThumbSize: 20, BarSize: 20,
        ArT: 30
    }
    static Statics := {
        AktywnaInstancjaSuwaka: 0, ; Wskaźnik na silnik używający pętli scrolla
        AktywneInstancje: [],      ; Globalny rejestr do Raycastingu
        AktywneBledy: [],          ; Stos otwartych okien błędów
        OstatniScrollTick: 0,      ; Zegar blokady wizualnej (Hover) i interakcji
        GlobFont: { Name: "Segoe UI", Size: 10 },
        TotalScale: 1.0,
        StanMButtonScroll: { Aktywny: false, TrybToggle: false, Instancja: 0, StartX: 0, StartY: 0, TickStart: 0, OstatnieVx: 0, OstatnieVy: 0, AccumX: 0.0, AccumY: 0.0, Fake: 0, LastCurId: 0, LastClipDir: "", LastScale: 1.0, Opcje: {}, CanX: false, CanY: false },
        PetlaMButtonScrollObj: 0,
        ZakonczMButtonScrollObj: 0,
        GlobalMouseHook: 0,
        GlobalHookCallback: 0,
        unikalneInstancje: Map() ; Rejestr instancji Singleton
    }

    static Motyw := {
        Tlo: "c363533",
        Tekst: "cE0E0E0",
        Ramka: "c484745",
        Przycisk: "c403F3D",
        Focus: "c504F4D",
        Nieaktywny: "c808080",
        Ostrzezenie: "cbd4646",
        Wklesly: "c302F2D",
        ParamFocus: 0.1,
        ParamHover: 0.05,
        FactorNieaktywny: 0.4,
        FactorRamki: 0.2,
        Tryb: 1          ; 0=Auto, 1=Ciemny, 2=Jasny
    }
    static MapaKolorow := Map(
        "white", "FFFFFF", "silver", "C0C0C0", "gray", "808080", "black", "000000",
        "red", "FF0000", "maroon", "800000", "yellow", "FFFF00", "olive", "808000",
        "lime", "00FF00", "green", "008000", "aqua", "00FFFF", "teal", "008080",
        "blue", "0000FF", "navy", "000080", "fuchsia", "FF00FF", "purple", "800080"
    )
}
/**
 * Klasa pomocnicza zawierająca ogólne narzędzia systemowe i matematyczne.
 */
class Utils extends Data {
    /**
     * @desc Formatuje liczbę do 2 miejsc po przecinku i usuwa nieznaczące zera.
     * @param {Number} liczba - Wartość wejściowa.
     * @param {Integer} [prec=2] - Liczba miejsc po przecinku.
     * @return {String} Zoptymalizowana tekstowa reprezentacja liczby.
     */
    Static FormatNum(liczba, prec) => RTrim(RTrim(Format("{:." prec "f}", liczba), "0"), ".")

    /**
     * Scales physical dimensions (x, y, w, h) in AHK options string based on current DPI.
     * Handles explicit values and relative modifiers (e.g., xp+10, y-20, w100).
     * @param {String} optionsStr - AHK options string.
     * @returns {String} Scaled options string.
     */
    static ScaleOptions(optionsStr) {
        if (Type(optionsStr) !== "String")
            return optionsStr

        myDpiScale := (A_ScreenDPI / 96) * SilnikGUI.Statics.TotalScale
        if (myDpiScale == 1.0)
            return optionsStr

        myPos := 1
        myLastPos := 1
        myNewOptions := ""

        while (myPos := RegExMatch(optionsStr, "i)(^|\s)([xywh][pms]*(?:[+-])?)(\d+)", &myMatch, myPos)) {
            myNewOptions .= SubStr(optionsStr, myLastPos, myMatch.Pos - myLastPos)
            myNewOptions .= myMatch[1] . myMatch[2] . Round(myMatch[3] * myDpiScale)
            myPos := myMatch.Pos + myMatch.Len
            myLastPos := myPos
        }

        return myNewOptions . SubStr(optionsStr, myLastPos)
    }

    /**
     * Konwertuje współrzędne kontrolki z obszaru klienta okna na ekranowe.
     * @param {GuiCtrl|Integer} obj - Obiekt kontrolki źródłowej (lub 0 dla kursora).
     * @param {Integer} hwnd - Uchwyt okna odniesienia (Client Area).
     * @param {Integer} [x=0] - Wyjście: X ekranowe kontrolki.
     * @param {Integer} [y=0] - Wyjście: Y ekranowe kontrolki.
     * @param {Integer} [w=0] - Wyjście: Szerokość kontrolki z GetPos.
     * @param {Integer} [h=0] - Wyjście: Wysokość kontolki z GetPos.
     * @return {Object} - Obiekt {x, y, w, h} (Screen Coords).
     */
    static ClientToScreen(obj, hwnd, &x := 0, &y := 0, &w := 0, &h := 0) {
        if !obj {
            pt := Buffer(8), DllCall("GetCursorPos", "Ptr", pt)
            x := NumGet(pt, 0, "Int"), y := NumGet(pt, 4, "Int")
            return { x: x, y: y, w: 0, h: 0 }
        }
        obj.GetPos(&x, &y, &w, &h)
        pz := Buffer(8), NumPut("Int", x, "Int", y, pz)
        DllCall("ClientToScreen", "Ptr", hwnd, "Ptr", pz)
        x := NumGet(pz, 0, "Int"), y := NumGet(pz, 4, "Int")
        return { x: x, y: y, w: w, h: h }
    }

    /**
     * Konwertuje współrzędne ekranowe/kontrolki na obszar klienta okna.
     * @param {GuiCtrl|Integer} obj - Obiekt kontrolki źródłowej (lub 0 dla kursora).
     * @param {Integer} hwnd - Uchwyt okna docelowego (Client Area).
     * @param {Integer} [x=0] - Wyjście: X względem klienta okna.
     * @param {Integer} [y=0] - Wyjście: Y względem klienta okna.
     * @param {Integer} [w=0] - Wyjście: Szerokość kontrolki z GetPos.
     * @param {Integer} [h=0] - Wyjście: Wysokość kontolki z GetPos.
     * @return {Object} - Obiekt {x, y, w, h} (Client Coords).
     */
    static ScreenToClient(obj, hwnd, &x := 0, &y := 0, &w := 0, &h := 0) {
        pt := Buffer(8)
        if !obj {
            DllCall("GetCursorPos", "Ptr", pt)
        } else {
            obj.GetPos(&x, &y, &w, &h)
            NumPut("Int", x, "Int", y, pt)
            parentHwnd := DllCall("GetAncestor", "Ptr", obj.Hwnd, "UInt", 1, "Ptr") ; GA_PARENT
            DllCall("ClientToScreen", "Ptr", parentHwnd, "Ptr", pt)
        }
        DllCall("ScreenToClient", "Ptr", hwnd, "Ptr", pt)
        x := NumGet(pt, 0, "Int"), y := NumGet(pt, 4, "Int")
        return { x: x, y: y, w: w, h: h }
    }

    /**
     * Łączy obiekt opcji z wartościami domyślnymi. Zapewnia bezpieczne rzutowanie podstawowych typów numerycznych.
     * @param {Object} [provided] - Opcje przekazane przez użytkownika.
     * @param {Object} defaults - Słownik oczekiwanych wartości domyślnych.
     * @returns {Object} - Kompletny, połączony obiekt konfiguracyjny.
     */
    static MergeOptions(provided?, defaults := {}) {
        if !IsSet(provided) || Type(provided) !== "Object"
            provided := {}
        for k, v in defaults.OwnProps() {
            if !provided.HasProp(k)
                provided.%k% := (Type(v) == "Object") ? Utils.MergeOptions({}, v) : v
            else if (Type(v) == "Object" && Type(provided.%k%) == "Object")
                provided.%k% := Utils.MergeOptions(provided.%k%, v)
            else if ((Type(v) == "Integer" || Type(v) == "Float") && IsNumber(provided.%k%))
                provided.%k% := Number(provided.%k%)
        }
        return provided
    }

    ; Ustawia tag WinAPI (właściwość okna).
    static SetTag(Hwnd, NazwaTaga, Wartosc := 1) => DllCall("SetProp", "Ptr", Hwnd, "Str", NazwaTaga, "Ptr", Wartosc)
    ; Pobiera tag WinAPI.
    static GetTag(Hwnd, NazwaTaga) => DllCall("GetProp", "Ptr", Hwnd, "Str", NazwaTaga, "Ptr")
    ; Usuwa tag WinAPI.
    static RemoveTag(Hwnd, NazwaTaga) => DllCall("RemoveProp", "Ptr", Hwnd, "Str", NazwaTaga)
}
/**
 * 1. WARSTWA MOTYWU (BASE)
 * Definicje kolorów, stałe konfiguracyjne i matematyka barw.
 */
class Motyw extends Utils {


    ; Mapa nazw kolorów HTML/CSS


    /**
     * Konwertuje nazwę koloru lub format z prefixami na czysty HEX.
     * @param {String} c - Nazwa (np. "red") lub kod (np. "0xFF0000", "cRed").
     */
    static PobierzHex(c) {
        c := StrLower(c)
        c := StrReplace(StrReplace(c, "0x", ""), "#", "")
        if (SubStr(c, 1, 1) == "c") { ; Obsługa formatu AHK "cRed" / "cFFFFFF"
            temp := SubStr(c, 2)
            if (Motyw.MapaKolorow.Has(temp) || (StrLen(temp) == 6 && IsXDigit(temp)))
                c := temp
        }
        return Motyw.MapaKolorow.Has(c) ? Motyw.MapaKolorow[c] : c
    }

    /**
     * Generuj odcień koloru.
     * @param {String} kolorBazowy - Kolor bazowy w formacie HEX.
     * @param {String} parametr - Wartość odcienia: liczba od -1 do 1 (ujemna przyciemnia, dodatnia rozjaśnia).
     */
    static Odcien(kolorBazowy, parametr) {
        if IsNumber(parametr) {
            if (parametr < 0)
                return SilnikGUI.MieszajKolory(kolorBazowy, "000000", Abs(parametr))
            else
                return SilnikGUI.MieszajKolory(kolorBazowy, "FFFFFF", parametr)
        }
    }

    /**
     * Miesza dwa kolory HEX.
     * @param {String} Kolor1 - Pierwszy kolor w formacie HEX.
     * @param {String} Kolor2 - Drugi kolor w formacie HEX.
     * @param {Number} waga - Waga mieszania (0-1). 0 = tylko Kolor1, 1 = tylko Kolor2.
     */
    static MieszajKolory(Kolor1, Kolor2, waga := 0.5) {
        h1 := Motyw.PobierzHex(Kolor1)
        h2 := Motyw.PobierzHex(Kolor2)

        if (StrLen(h1) != 6 || StrLen(h2) != 6 || !IsXDigit(h1) || !IsXDigit(h2))
            return StrReplace(Kolor2, "c", "")

        r := Integer(Integer("0x" SubStr(h1, 1, 2)) * (1 - waga) + Integer("0x" SubStr(h2, 1, 2)) * waga)
        g := Integer(Integer("0x" SubStr(h1, 3, 2)) * (1 - waga) + Integer("0x" SubStr(h2, 3, 2)) * waga)
        b := Integer(Integer("0x" SubStr(h1, 5, 2)) * (1 - waga) + Integer("0x" SubStr(h2, 5, 2)) * waga)

        return Format("{:02X}{:02X}{:02X}", r, g, b)
    }

    /**
     * Kompleksowa funkcja konfigurująca kolorystykę dla SilnikGUI oraz skryptu.
     * Automatycznie wylicza odcienie ramek, przycisków i tekstów na podstawie koloru bazowego.
     * 
     * @param {String} bazowyHex - Główny kolor tła (np. "363533").
     * @param {Number} [factorRamka=0.2] - Współczynnik rozjaśnienia ramki.
     * @param {Number} [factorNieaktywny=0.4] - Współczynnik rozjaśnienia tekstu nieaktywnego.
     * @param {Number} [factorTekst=0.8] - Współczynnik rozjaśnienia głównego tekstu.
     * @param {String} [warnHex="bd4646"] - Kolor ostrzegawczy (np. dla błędów).
     * @param {Number} [factorPrzycisk=0.1] - Współczynnik rozjaśnienia przycisku.
     * @param {Number} [paramFocus=0.1] - Siła rozjaśnienia fokusie
     * @param {Number} [factorWklesly=-0.1] - Współczynnik przyciemnienia tła elementów wklęsłych (Edit, Checkbox).
     */
    static Konfiguruj(bazowyHex, factorRamka := 0.2, factorNieaktywny := 0.4, factorTekst := 0.8, warnHex := "bd4646", factorPrzycisk := 0.1, paramFocus := 0.1, factorWklesly := -0.1) {
        ; Czyszczenie HEX
        bazowy := RegExReplace(Motyw.PobierzHex(bazowyHex), "[^0-9a-fA-F]", "")
        warn := RegExReplace(Motyw.PobierzHex(warnHex), "[^0-9a-fA-F]", "")

        ; Awaryjnie: Ciemny szary
        if (StrLen(bazowy) != 6)
            bazowy := "363533"

        ; --- AUTO-DETEKCJA JASNOŚCI ---
        r := Integer("0x" SubStr(bazowy, 1, 2))
        g := Integer("0x" SubStr(bazowy, 3, 2))
        b := Integer("0x" SubStr(bazowy, 5, 2))
        isLight := false
        ; Luminancja > 128 = Jasny
        if ((r * 299 + g * 587 + b * 114) / 1000 > 128) {
            isLight := true
            factorRamka := -Abs(factorRamka)
            factorNieaktywny := -Abs(factorNieaktywny)
            factorTekst := -Abs(factorTekst)
            factorPrzycisk := -Abs(factorPrzycisk)
            paramFocus := -Abs(paramFocus)
        }

        ; 1. Parametry globalne
        SilnikGUI.Motyw.Tlo := bazowy
        SilnikGUI.Motyw.FactorRamki := factorRamka
        SilnikGUI.Motyw.FactorNieaktywny := factorNieaktywny
        SilnikGUI.Motyw.Ramka := SilnikGUI.Odcien(bazowy, factorRamka)
        SilnikGUI.Motyw.Przycisk := SilnikGUI.Odcien(bazowy, factorPrzycisk)
        SilnikGUI.Motyw.Focus := SilnikGUI.Odcien(bazowy, factorPrzycisk + paramFocus)
        SilnikGUI.Motyw.ParamFocus := paramFocus
        SilnikGUI.Motyw.ParamHover := paramFocus * 0.6

        if (isLight)
            SilnikGUI.Motyw.Wklesly := SilnikGUI.Odcien(bazowy, factorWklesly)
        else
            SilnikGUI.Motyw.Wklesly := SilnikGUI.Odcien(bazowy, factorWklesly)

        ; 2. Teksty (Prefix 'c' dla Gui)
        SilnikGUI.Motyw.Tekst := "c" . SilnikGUI.Odcien(bazowy, factorTekst)

        ; Bez prefixu (elastyczne)
        SilnikGUI.Motyw.Nieaktywny := SilnikGUI.Odcien(bazowy, factorNieaktywny)
        SilnikGUI.Motyw.Ostrzezenie := warn
    }
}

/**
 * 2. WARSTWA GRAFIKI
 * Rysowanie ramek, style, tooltipy i okna błędów.
 */
class Grafika extends Motyw {


    /**
     * Tworzy wizualną ramkę składającą się z dwóch prostokątów (zewnętrznego i wewnętrznego).
     * Pozwala uzyskać efekt obramowania o dowolnym kolorze i grubości.
     * Zwraca obiekt z kontrolkami, co pozwala na ich późniejsze przesuwanie/skalowanie.
     * @param {Gui} guiObj - Obiekt GUI.
     * @param {Number} x - Pozycja X.
     * @param {Number} y - Pozycja Y.
     * @param {Number} w - Szerokość całkowita ramki.
     * @param {Number} h - Wysokość całkowita ramki.
     * @param {String} kolorRamki - Kolor zewnętrzny (obrys).
     * @param {Integer} [grubosc=2] - Grubość ramki w px.
     * @param {Boolean} [fixed=false] - Czy kolor ma być stały (ignorować motyw).
     * @param {Boolean} [wypelnienie=false] - True=1 pełna kontrolka (Solid), False=2 kontrolki (Hollow/Mask).
     * @returns {Object} - Obiekt Proxy (Outer).
     */
    static RysujObrys(guiObj, x, y, w, h, kolorRamki, grubosc := 2, fixed := false, wypelnienie := false) {
        Ctrls := []

        if (wypelnienie) {
            ; --- TRYB 1: SOLID (Pojedynczy blok tła) ---
            ; Używany dla teł kontrolek (np. Edit, ListBox)
            Outer := guiObj.Add("Text", "x" . x . " y" . y . " w" . w . " h" . h . " +0x4000000 +0x100 Background" . kolorRamki)
            Ctrls.Push(Outer)
            MainCtrl := Outer
        } else {
            ; --- TRYB 2: 4 PASKI (Ramka pusta w środku) ---
            ; Używany dla ramek ozdobnych i grup. Gwarantuje brak kolizji w centrum.

            ; Top & Bot (Pełna szerokość)
            Top := guiObj.Add("Text", "x" . x . " y" . y . " w" . w . " h" . grubosc . " +0x4000000 +0x100 Background" . kolorRamki)
            Bot := guiObj.Add("Text", "x" . x . " y" . (y + h - grubosc) . " w" . w . " h" . grubosc . " +0x4000000 +0x100 Background" . kolorRamki)

            ; Left & Right (Wysokość pomniejszona o grubości góra/dół, aby nie nakładać się na rogi)
            hSide := Max(0, h - 2 * grubosc)
            Left := guiObj.Add("Text", "x" . x . " y" . (y + grubosc) . " w" . grubosc . " h" . hSide . " +0x4000000 +0x100 Background" . kolorRamki)
            Right := guiObj.Add("Text", "x" . (x + w - grubosc) . " y" . (y + grubosc) . " w" . grubosc . " h" . hSide . " +0x4000000 +0x100 Background" . kolorRamki)

            Ctrls.Push(Top, Bot, Left, Right)
            MainCtrl := Top ; Kotwica pozycyjna
        }

        ; Konfiguracja wspólna (Tagowanie i Z-Order)
        for c in Ctrls {
            c.IsFrame := true
            (fixed) && c.FixedColor := true
            ; Z-Order: Bottom (Na sam spód)
            DllCall("SetWindowPos", "Ptr", c.Hwnd, "Ptr", 1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
        }

        MainCtrl.GetPos(&rX, &rY)

        ; Proxy Object (Udaje pojedynczą kontrolkę)
        Proxy := {
            Gui: guiObj,
            Hwnd: MainCtrl.Hwnd,
            x: rX, y: rY, w: w, h: h,
            Ctrls: Ctrls,
            ; Kompatybilność wsteczna (dla MonitorujWyjscie i logiki resize)
            Top: (wypelnienie ? MainCtrl : Ctrls[1]),
            Bot: (wypelnienie ? MainCtrl : Ctrls[2]),
            Left: (wypelnienie ? MainCtrl : Ctrls[3]),
            Right: (wypelnienie ? MainCtrl : Ctrls[4])
        }

        Proxy.DefineProp("Move", { Call: (this, nx := "", ny := "", nw := "", nh := "") => (
            (nx != "") && this.x := nx, (ny != "") && this.y := ny, (nw != "") && this.w := nw, (nh != "") && this.h := nh,
            (wypelnienie)
                ? this.Ctrls[1].Move(this.x, this.y, this.w, this.h)
            : (
                this.Top.Move(this.x, this.y, this.w, grubosc),
                this.Bot.Move(this.x, this.y + this.h - grubosc, this.w, grubosc),
                this.Left.Move(this.x, this.y + grubosc, grubosc, Max(0, this.h - 2 * grubosc)),
                this.Right.Move(this.x + this.w - grubosc, this.y + grubosc, grubosc, Max(0, this.h - 2 * grubosc))
            )
        ) })

        Proxy.DefineProp("GetPos", { Call: (this, &x?, &y?, &w?, &h?) => (
            this.Ctrls[1].GetPos(&tx, &ty),
            (IsSet(x) && x := tx),
            (IsSet(y) && y := ty),
            (IsSet(w) && w := this.w),
            (IsSet(h) && h := this.h)
        ) })

        Batch(metoda, args*) {
            for c in Ctrls
                c.%metoda%(args*)
        }

        Proxy.DefineProp("Opt", { Call: (this, o) => Batch("Opt", o) })
        Proxy.DefineProp("OnEvent", { Call: (this, evt, cb) => Batch("OnEvent", evt, cb) })
        Proxy.DefineProp("Redraw", { Call: (this) => Batch("Redraw") })

        Proxy.DefineProp("ParentCtrl", {
            set: (this, val) => Batch("DefineProp", "ParentCtrl", { Value: val }),
            get: (this) => this.Ctrls[1].ParentCtrl
        })

        return Proxy
    }

    /**
     * Oblicza pełny Bounding Box dla kontrolki/grupy i jej dekoracji (DRY).
     * @param
     */
    static ObliczBoundingBox(Cele) {
        if !IsObject(Cele)
            return { x: 0, y: 0, w: 0, h: 0 }
        if (Type(Cele) != "Array")
            Cele := [Cele]

        minX := 99999, minY := 99999, maxX := -99999, maxY := -99999
        CheckBounds(obj) {
            if !obj
                return
            if HasProp(obj, "Ctrls") {
                for subCtrl in obj.Ctrls
                    CheckBounds(subCtrl)
                return
            }
            if (HasProp(obj, "IsDummy") && obj.IsDummy)
                return
            try {
                obj.GetPos(&ox, &oy, &ow, &oh)
                minX := Min(minX, ox), minY := Min(minY, oy)
                maxX := Max(maxX, ox + ow), maxY := Max(maxY, oy + oh)
            }
        }
        for c in Cele {
            CheckBounds(c)
            (HasProp(c, "EtykietaCtrl")) && CheckBounds(c.EtykietaCtrl)
            (HasProp(c, "Ramka")) && CheckBounds(c.Ramka)
            (HasProp(c, "ArrowCtrl")) && CheckBounds(c.ArrowCtrl)
            (HasProp(c, "PlaceholderCtrl")) && CheckBounds(c.PlaceholderCtrl)
        }
        if (minX == 99999)
            return { x: 0, y: 0, w: 0, h: 0 }
        return { x: minX, y: minY, w: maxX - minX, h: maxY - minY }
    }

    /**
     * Rysuje ramkę obejmującą grupę kontrolek (od StartCtrl do ostatniej dodanej).
     * @param {GuiCtrl} StartCtrl - Pierwsza kontrolka w grupie (musi być już dodana do Silnika).
     * @param {GuiCtrl|Integer} [EndCtrl=0] - Ostatnia kontrolka w grupie. 0 = Tylko StartCtrl.
     * @param {Integer} [Margin=10] - Margines wewnętrzny ramki (px).
     * @param {String} [Kolor=""] - Kolor ramki (domyślnie z motywu).
     * @param {Integer} [Grubosc=2] - Grubość linii.
     * @param {Intiger} [Dynamic=0] - obsługa dynamicznego move
     * @param {Boolean} [ApplyScale=true] - Czy skalować margines i grubość linii zgodnie z DPI ekranu.
     */
    Ramka(StartCtrl, EndCtrl := 0, Margin := 10, Kolor := "", Grubosc := 2, Dynamic := 0, ApplyScale := true) {
        Skala := (A_ScreenDPI / 96) * SilnikGUI.Statics.TotalScale
        Margin := ApplyScale ? Round(Margin * Skala) : Margin
        Grubosc := ApplyScale ? Round(Grubosc * Skala) : Grubosc

        InputObj := StartCtrl ; Zachowaj referencję do potencjalnej GrupyKontrolek
        ; Obsługa Wrapperów (GrupaKontrolek)
        if (HasProp(StartCtrl, "MainCtrl")) {
            StartCtrl := StartCtrl.MainCtrl
        }
        if (EndCtrl && HasProp(EndCtrl, "MainCtrl")) {
            EndCtrl := EndCtrl.MainCtrl
        }

        if !StartCtrl
            return

        ; 1. Wybierz cele (Głupi mechanizm: Start -> End)
        Cele := []
        if (EndCtrl) {
            sIdx := 0, eIdx := 0

            ; [FIX] Buduj mapę znanych kontrolek, aby odzyskać właściwości (.Ramka) utracone przy iteracji GuiObj
            Znane := Map()
            for c in this.Stan.Kontrolki
                try Znane[c.Hwnd] := c
            if (StartCtrl)
                Znane[StartCtrl.Hwnd] := StartCtrl
            if (EndCtrl)
                Znane[EndCtrl.Hwnd] := EndCtrl

            ; [FIX] Iteruj po GUI, do którego należy StartCtrl (obsługa ChildGui)
            TargetGui := StartCtrl.Gui
            Wszystkie := []
            for c in TargetGui
                Wszystkie.Push(Znane.Has(c.Hwnd) ? Znane[c.Hwnd] : c)

            for i, c in Wszystkie {
                if (c.Hwnd == StartCtrl.Hwnd)
                    sIdx := i
                if (c.Hwnd == EndCtrl.Hwnd)
                    eIdx := i
            }
            if (sIdx && eIdx && eIdx >= sIdx) {
                Loop (eIdx - sIdx + 1)
                    Cele.Push(Wszystkie[sIdx + A_Index - 1])
            } else {
                Cele.Push(StartCtrl) ; Fallback
                if (EndCtrl)
                    Cele.Push(EndCtrl)
            }
        } else {
            Cele.Push(StartCtrl)
        }

        ; Determine Mode
        isSingle := (Cele.Length == 1)
        wypelnienie := (isSingle && Margin == 0)

        ; 2. Oblicz BoundingBox (Union Rect dla wszystkich celów i ich dekoracji - DRY)
        box := Grafika.ObliczBoundingBox(Cele)

        ; 3. Rysuj
        if (box.w > 0) {
            Outer := SilnikGUI.RysujObrys(StartCtrl.Gui,
                box.x - Margin - Grubosc, box.y - Margin - Grubosc,
                box.w + 2 * Margin + 2 * Grubosc,
                box.h + 2 * Margin + 2 * Grubosc,
                (Kolor == "" ? SilnikGUI.Motyw.Ramka : Kolor),
                Grubosc, (Kolor != ""), wypelnienie)

            ; [AUTO-BINDING] Automatyczne odświeżanie przy ruchu celów (Observer Pattern)
            ; Zamiast ręcznego .Dopasuj(), wpinamy się w metodę .Move() kontrolek
            if (Dynamic == 1) {
                Odswiez := (*) => (
                    b := Grafika.ObliczBoundingBox(Cele),
                    (b.w > 0) && Outer.Move(b.x - Margin - Grubosc, b.y - Margin - Grubosc, b.w + 2 * Margin + 2 * Grubosc, b.h + 2 * Margin + 2 * Grubosc)
                )

                for c in Cele {
                    if !HasProp(c, "RamkaHooks") {
                        c.RamkaHooks := []
                        ; Hookowanie metody Move: Wykonaj oryginał -> Wykonaj odświeżanie ramek
                        OrigMove := HasProp(c, "Move") ? c.Move : c.Base.Move
                        c.DefineProp("Move", { Call: (self, p*) => (OrigMove(self, p*), RunHooks(self)) })
                        RunHooks(self) {
                            for cb in self.RamkaHooks
                                cb()
                        }
                    }
                    c.RamkaHooks.Push(Odswiez)
                }

                ; [FIX] Oznacz elementy ramki dynamicznej, aby Pokaz() ich nie przesuwał
                ; (Ramka sama się przesunie na właściwe miejsce dzięki hookom na kontrolkach-celach)
                for c in Outer.Ctrls ; Teraz działa poprawnie dla obu trybów (1 lub 4 kontrolki)
                    c.SkipAutoShift := true

                ; [FIX] Wymuś natychmiastowe odświeżenie (synchronizacja pozycji startowej z logiką dynamiczną)
                Odswiez()
            }
            Outer.Cele := Cele ; Zapisz cele w obiekcie

            ; [AUTO-BINDING] Jeśli cel to GrupaKontrolek, dodaj ramkę do jej elementów, aby działało Move()
            if (HasProp(InputObj, "Elementy") && IsObject(InputObj.Elementy)) {
                InputObj.Elementy.Push(Outer)
            }
            return Outer
        }
    }

    /**
     * Aplikuje styl wizualny do kontrolki w zależności od stanu.
     * @param {GuiCtrl} ctrl - Kontrolka.
     * @param {Integer} stan - 0=Normal, 1=Hover, 2=Focus.
     * @param {String} [kolorRamki=""] - Opcjonalny bazowy kolor ramki (dla stanu nieaktywnego).
     * @param {String} [kolorPrzycisku=""] - Opcjonalny bazowy kolor przycisku.
     * @param {String} [kolorTekstu=""] - Opcjonalny bazowy kolor tekstu.
     */
    static NadajStyl(ctrl, stan, kolorRamki := "", kolorPrzycisku := "", kolorTekstu := "", KolorMotywu := "") {
        ; 1. Wylicz parametr (Ternary)
        param := (stan = 3 ? SilnikGUI.Motyw.ParamFocus + SilnikGUI.Motyw.ParamHover : (stan = 2 ? SilnikGUI.Motyw.ParamFocus : (stan = 1 ? SilnikGUI.Motyw.ParamHover : 0)))
        DajKolor := (baza, wplyw) => (wplyw = 0 ? baza : SilnikGUI.Odcien(baza, wplyw)) ; Lambda pomocnicza
        (kolorRamki == "") && kolorRamki := SilnikGUI.Motyw.Ramka
        (kolorPrzycisku == "") && kolorPrzycisku := SilnikGUI.Motyw.Przycisk
        (kolorTekstu == "") && kolorTekstu := SilnikGUI.Motyw.Tekst
        (KolorMotywu == "") && KolorMotywu := SilnikGUI.Motyw.Tlo

        ; 2. Aplikuj styl (Switch)
        switch (HasProp(ctrl, "Rola") ? ctrl.Rola : ctrl.Type) {
            ; [FIX] Odwrócona kolejność: Najpierw RAMKA (Tło), potem KONTROLKA (Treść)
            ; Zapobiega zamazywaniu kontrolki przez ramkę podczas odświeżania
            case "CSBarButton":
                ctrl.Opt("Background" . DajKolor(KolorMotywu, param) . " c" . DajKolor(kolorTekstu, param) . " Redraw")
            case "CustomButton":
                (HasProp(ctrl, "Ramka")) && ctrl.Ramka.Opt("Background" . DajKolor(kolorRamki, param) . " Redraw")
                ctrl.Opt("Background" . DajKolor(kolorPrzycisku, param) . " c" . DajKolor(kolorTekstu, param) . " Redraw")
            case "Checkbox":
                ctrl.Ramka.Opt("Background" . DajKolor(kolorRamki, param) . " Redraw")
                ctrl.Opt("Background" . DajKolor(SilnikGUI.Motyw.Wklesly, param) . " c" . DajKolor(kolorTekstu, param) . " Redraw")
            case "DDList":
                HasProp(ctrl, "Ramka") && ctrl.Ramka.Opt("Background" . DajKolor(kolorRamki, param) . " Redraw")
                HasProp(ctrl, "SepCtrl") && ctrl.SepCtrl.Opt("Background" . DajKolor(kolorRamki, param) . " Redraw")
                HasProp(ctrl, "ArrowCtrl") && ctrl.ArrowCtrl.Opt("Background" . DajKolor(SilnikGUI.Motyw.Wklesly, param) . " Redraw")
                ctrl.Opt("Background" . DajKolor(SilnikGUI.Motyw.Wklesly, param) . " Redraw")
            case "Edit":
                (HasProp(ctrl, "Ramka")) && ctrl.Ramka.Opt("Background" . DajKolor(kolorRamki, param) . " Redraw")
                (HasProp(ctrl, "PlaceholderCtrl")) && ctrl.PlaceholderCtrl.Opt("Background" . DajKolor(ctrl.PlaceholderCtrl.KolorBazowy, param) . " Redraw")
                ctrl.Opt("Background" . DajKolor(ctrl.KolorBazowyTla, param) . " Redraw")
            case "Panel":
                (HasProp(ctrl, "Ramka")) && ctrl.Ramka.Opt("Background" . DajKolor(kolorRamki, param) . " Redraw")
        }
    }

    ;mignięcie (kolizja scroll-limit/kliknięcie)
    static EfektFlash(ctrl, czas := 100) {
        ctrl.FlashEndTime := A_TickCount + czas
        try ctrl.Gui.FlashEndTime := A_TickCount + czas ; Wybudzenie MonitorujStan
        SilnikGUI.NadajStyl(ctrl, 0) ; Wymuś stan 'Normal' (wygaszenie)
    }

    /**
     * Odświeża tła elementów listy (DDList/Menu).
     * @param {Array} listaCtrls - Tablica kontrolek.
     * @param {Integer} wybranyIdx - Indeks aktywnego elementu.
     */
    static AktualizujListe(listaCtrls, wybranyIdx) {
        if (!listaCtrls || listaCtrls.Length = 0)
            return
        for i, c in listaCtrls {
            bg := (i == wybranyIdx) ? SilnikGUI.Motyw.Focus : SilnikGUI.Motyw.Przycisk
            ram := (i == wybranyIdx) ? SilnikGUI.Odcien(SilnikGUI.Motyw.Ramka, SilnikGUI.Motyw.ParamFocus) : SilnikGUI.Motyw.Ramka
            if (HasProp(c, "Main")) { ; Obsługa złożonych elementów (Center Mode)
                c.Main.Opt("Background" . bg . " Redraw")
                (HasProp(c, "Left")) && c.Left.Opt("Background" . bg . " Redraw")
                (HasProp(c, "Right2")) && c.Right2.Opt("Background" . bg . " Redraw")
                (HasProp(c, "Right1")) && c.Right1.Opt("Background" . ram . " Redraw")
            } else {
                c.Opt("Background" . bg . " Redraw")
            }
        }
    }

    /**
     * Oblicza faktyczny rozmiar zajmowany przez kontrolki (Canvas).
     * Ignoruje elementy techniczne (Dummy, Ramki).
     * @param {GuiCtrl} [ignorujCtrl=0] - Opcjonalna kontrolka do pominięcia w pomiarach (np. ta, która właśnie zmienia rozmiar).
     * @returns {Object} {W: Number, H: Number}
     */
    ObliczObszarRoboczy(ignorujCtrl := 0) {
        ; [FIX] Odczyt z gwarantowanej zmiennej stanu
        if (!ignorujCtrl && this.Stan.LastObszarTick && A_TickCount - this.Stan.LastObszarTick < 50)
            return this.Stan.LastObszar

        maxW := 0, maxH := 0
        TargetObj := this.Stan.UseChild ? this.Stan.ChildGui : this.GuiObj
        for ctrl in TargetObj {
            ; [FIX] Ignoruj tylko Dummy. Ramki (IsFrame) są częścią layoutu i muszą być mierzone!
            if (HasProp(ctrl, "IsDummy") && ctrl.IsDummy)
                continue

            ; [FIX] Pomijanie aktualnie skalowanej kontrolki i jej dekoracji (zapobiega blokowaniu shrinka)
            if (ignorujCtrl && (ctrl.Hwnd == ignorujCtrl.Hwnd || (HasProp(ctrl, "ParentCtrl") && ctrl.ParentCtrl.Hwnd == ignorujCtrl.Hwnd)))
                continue

            ctrl.GetPos(&cX, &cY, &cW, &cH)
            maxW := Max(maxW, cX + cW + this.Stan.PadR)
            maxH := Max(maxH, cY + cH + this.Stan.PadD)
        }
        res := { W: maxW, H: maxH }
        if (!ignorujCtrl) {
            this.Stan.LastObszar := res
            this.Stan.LastObszarTick := A_TickCount
        }
        return res
    }
}

/**
 * 3. WARSTWA LOGIKI
 * Walidacja, obsługa wejścia, skróty klawiszowe i matematyka.
 */
class Logika extends Grafika {
    static WatchdogiClick := []
    /**
     * Centralna obsługa wejścia (Scroll/Klawiatura) oparta na komunikatach Windows.
     * Zastępuje Hotkey, eliminując ryzyko Stack Overflow przy współpracy z mouse_ctrl.
     */
    static ObslugaZdarzenSystemowych(wParam, lParam, msg, hwnd) {
        if (msg == 0x0020) { ; WM_SETCURSOR
            if SilnikGUI.Statics.StanMButtonScroll.Aktywny {
                DllCall("SetCursor", "Ptr", 0) ; Ukrywamy natywny kursor
                return 1
            }
        }

        if (msg == 0x0207) { ; WM_MBUTTONDOWN
            if SilnikGUI.Statics.StanMButtonScroll.Aktywny
                return (SilnikGUI.ZakonczMButtonScroll(), 1)
            if SilnikGUI.Statics.AktywnaInstancjaSuwaka
                return 0
            if SilnikGUI.PasekPrzewijania.CzyGotowyNaMButtonScroll(true, &Silnik)
                return (SilnikGUI.PasekPrzewijania.UruchomMButtonScroll(Silnik), 1)
        }


        ; 1. SCROLL MYSZĄ (WM_MOUSEWHEEL - 0x020A, WM_MOUSEHWHEEL - 0x020E)
        if (msg == 0x020A || msg == 0x020E) {
            delta := (wParam >> 16)
            (delta > 0x7FFF) && delta -= 0x10000 ; Konwersja na signed int

            isHScroll := (msg == 0x020E)
            kierunek := isHScroll ? ((delta > 0) ? -1 : 1) : ((delta > 0) ? 1 : -1)

            if (hUnder := SilnikGUI.GetRealHwndUnderMouse()) {
                try {
                    gHwnd := GuiFromHwnd(hUnder) ? hUnder : GuiCtrlFromHwnd(hUnder).Gui.Hwnd
                    if (gHwnd && Utils.GetTag(gHwnd, "IsSilnikTooltip"))
                        return 1 ; Pożeraj scrolla
                }
            }

            ; Globalny rejestr (Bypass problemu Child/Root)
            if SilnikGUI.Statics.AktywnaInstancjaSuwaka {
                SilnikGUI.Statics.AktywnaInstancjaSuwaka.Stan.ScrollDelta := kierunek
                return 1
            }

            SilnikGUI.AkcjaScrollBar(kierunek, isHScroll)
            return 1
        }

        ; 2. KLAWIATURA (WM_KEYDOWN - 0x100, WM_SYSKEYDOWN - 0x0104 dla Alt)
        if (msg == 0x0100 || msg == 0x0104) {
            vk := wParam
            if (vk == 0x0D) {  ; ENTER
                stan := SilnikGUI.PobierzStanEnter()
                if (stan == 1) ; Obsługiwana kontrolka
                    return (SilnikGUI.AkcjaEnter(), 0)
                if (stan == 2) ; [FIX] WM_NEXTDLGCTL (0x28): 0=Next, 1=Prev. Rozkaz systemowy, nie narusza stanu klawiszy (Ctrl/Shift).
                    return (PostMessage(0x0028, GetKeyState("Shift"), 0, , "ahk_id " DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")), 0)
            }
            if (vk == 0x1B) { ; ESC
                if SilnikGUI.Statics.StanMButtonScroll.Aktywny
                    return (SilnikGUI.ZakonczMButtonScroll(), 1)
            }
            ; --- STRZAŁKI (Standard + Numpad, Pion + Poziom) ---
            isUp := (vk == 0x26 || vk == 0x68), isDown := (vk == 0x28 || vk == 0x62)
            isLeft := (vk == 0x25 || vk == 0x64), isRight := (vk == 0x27 || vk == 0x66)

            if (isUp || isDown || isLeft || isRight) {
                kierunek := (isUp || isLeft) ? 1 : -1
                isHoriz := (isLeft || isRight)

                ctrl := SilnikGUI.PobierzKontrolkeFocus()

                ; 1. Kontrolki natywne (Edit) potrzebują systemowego zachowania
                if (ctrl && (HasProp(ctrl, "ArrowNeed") || (isHoriz && HasProp(ctrl, "HArrowNeed")) || (!isHoriz && HasProp(ctrl, "VArrowNeed")))) {
                    if (HasProp(ctrl, "SledzKaretke") && ctrl.SledzKaretke)
                        SetTimer(ObjBindMethod(ctrl.Gui.Silnik, "SledzKaretke", ctrl), -10)
                    return ; Przepuść zdarzenie do systemu
                }

                prop := isHoriz ? "HScrollAction" : "VScrollAction"

                ; 2. Kontrolki UI - systemowy Auto-Repeat Delay
                if (ctrl && HasProp(ctrl, prop))
                    return (ctrl.%prop%(kierunek), 0)
                if (ctrl && HasProp(ctrl, "ScrollAction"))
                    return (ctrl.ScrollAction(kierunek), 0)

                ; 3. Płynny scroll okna (własny Timer omijający 500ms blokadę systemu)
                if ((lParam >> 30) & 1)
                    return 0 ; Ignoruj systemowy auto-repeat

                keyName := GetKeyName(Format("vk{:x}", vk))

                WypompujPed() {
                    if !GetKeyState(keyName, "P")
                        return SetTimer(WypompujPed, 0)
                    SilnikGUI.AkcjaScrollBar(kierunek, isHoriz, true)
                }

                WypompujPed() ; Pierwszy natychmiastowy skok
                SetTimer(WypompujPed, this.ConfigScroll.ArT) ; Start płynnej serii
                return 0
            }
        }
    }

    static PobierzStanEnter() {
        try {
            if (hwnd := ControlGetHwnd(ControlGetFocus("A"), "A"))
                if (ctrl := GuiCtrlFromHwnd(hwnd)) {
                    if HasProp(ctrl, "NativeEnter")
                        return 0 ; Ignoruj (przepuść zdarzenie do systemu)
                    return HasProp(ctrl, "OnEnter") ? 1 : 2
                }
        }
        return 0
    }

    static AkcjaEnter() {
        try {
            if (hwnd := ControlGetHwnd(ControlGetFocus("A"), "A")) && (ctrl := GuiCtrlFromHwnd(hwnd)) && HasProp(ctrl, "OnEnter")
                ctrl.OnEnter()
        }
    }

    static AkcjaScrollBar(kierunek, isHScroll := false, arrows := false) {
        ignorujKontrolki := (A_TickCount - SilnikGUI.Statics.OstatniScrollTick < 150)
        isHoriz := isHScroll

        ; 1. KLAWIATURA (Bezpośredni strzał do silnika z fokusem)
        if (arrows) {
            if (ctrl := SilnikGUI.PobierzKontrolkeFocus()) && HasProp(ctrl, "Gui") && HasProp(ctrl.Gui, "Silnik")
                SilnikGUI.PasekPrzewijania._WykonajScrollNaSilniku(ctrl.Gui.Silnik, kierunek, isHoriz, { Vstep: this.ConfigScroll.stepYAr, Hstep: this.ConfigScroll.stepXAr })
            return
        }

        isHoriz := isHScroll || GetKeyState("Shift", "P")

        ; 2. MYSZ (Z-Order Climb przez WinAPI z obsługą +Owner)
        stanMyszy := { trybMyszy: true, chronKontrolki: ignorujKontrolki, ctrlPobrano: false, ctrlUnderMouse: 0, Vstep: this.ConfigScroll.stepYWh, Hstep: this.ConfigScroll.stepXWh }

        curr := SilnikGUI.GetRealHwndUnderMouse()
        hDesktop := DllCall("GetDesktopWindow", "Ptr")
        while (curr && curr != hDesktop) {
            try {
                if ((g := GuiFromHwnd(curr)) && HasProp(g, "Silnik")) {
                    Silnik := g.Silnik
                    Utils.ScreenToClient(0, Silnik.GuiObj.Hwnd, &cX, &cY)
                    stanMyszy.cX := cX, stanMyszy.cY := cY

                    if SilnikGUI.PasekPrzewijania._WykonajScrollNaSilniku(Silnik, kierunek, isHoriz, stanMyszy)
                        return
                }
            }
            parent := DllCall("GetAncestor", "Ptr", curr, "UInt", 1, "Ptr") ; GA_PARENT
            curr := (parent && parent != hDesktop) ? parent : DllCall("GetWindow", "Ptr", curr, "UInt", 4, "Ptr") ; GW_OWNER
        }

        ; 3. FALLBACK GLOBALNY MYSZY (Brak silnika, czysta kontrolka)
        if (!ignorujKontrolki) {
            if (!stanMyszy.ctrlPobrano)
                stanMyszy.ctrlUnderMouse := SilnikGUI.ObslugaInterakcji(0, 0, 0, 0, true)
            SilnikGUI._WykonajScrollNaKontrolce(stanMyszy.ctrlUnderMouse, kierunek, isHoriz)
        }
    }

    ; Pomocnik delegujący scroll do natywnej kontrolki pod myszą.
    static _WykonajScrollNaKontrolce(ctrl, kierunek, isHoriz) {
        prop := isHoriz ? "HScrollAction" : "VScrollAction"
        ctrl := SilnikGUI.RozwiazKontrolke(ctrl)
        if (ctrl && SilnikGUI.CzyMoznaInterakcja(ctrl)) {
            if HasProp(ctrl, prop)
                return (ctrl.%prop%(kierunek), true)
            if HasProp(ctrl, "ScrollAction")
                return (ctrl.ScrollAction(kierunek), true)
        }
        return false
    }


    static PobierzKontrolkeFocus() {
        try {
            if (hwnd := ControlGetHwnd(ControlGetFocus("A"), "A"))
                return GuiCtrlFromHwnd(hwnd)
        }
        return 0
    }

    /**
     * @desc Niskopoziomowy Raycast zastępujący MouseGetPos.
     * Omija błędy 16-bitowe Windowsa dla szerokich kontrolek i ucinania regionów, respektując Z-Order.
     * @return {Integer} - Najgłębszy HWND pod kursorem należący do skryptu (lub 0).
     */
    static GetRealHwndUnderMouse() {
        DllCall("GetCursorPos", "Ptr", pt := Buffer(8))
        sX := NumGet(pt, 0, "Int"), sY := NumGet(pt, 4, "Int")
        hCtrl := (A_PtrSize == 8) ? DllCall("WindowFromPoint", "Int64", NumGet(pt, 0, "Int64"), "Ptr") : DllCall("WindowFromPoint", "Int", sX, "Int", sY, "Ptr")
        if (hCtrl) {
            Loop 5 {
                ptClient := Buffer(8)
                NumPut("Int", sX, "Int", sY, ptClient)
                DllCall("ScreenToClient", "Ptr", hCtrl, "Ptr", ptClient)
                hChild := (A_PtrSize == 8) ? DllCall("ChildWindowFromPointEx", "Ptr", hCtrl, "Int64", NumGet(ptClient, 0, "Int64"), "UInt", 1, "Ptr") : DllCall("ChildWindowFromPointEx", "Ptr", hCtrl, "Int", NumGet(ptClient, 0, "Int"), "Int", NumGet(ptClient, 4, "Int"), "UInt", 1, "Ptr")
                if (!hChild || hChild == hCtrl)
                    break
                hCtrl := hChild
            }
            try if (WinGetPID("ahk_id " hCtrl) == ProcessExist())
                return hCtrl
        }
        return 0
    }

    static PobierzKontrolkePodMyszka() {
        hCtrl := SilnikGUI.GetRealHwndUnderMouse()
        try {
            if (hCtrl && (ctrl := GuiCtrlFromHwnd(hCtrl))) {
                lider := SilnikGUI.RozwiazKontrolke(ctrl)
                if (IsObject(lider) && SilnikGUI.CzyMoznaInterakcja(lider))
                    if HasProp(lider, "ScrollAction") || HasProp(lider, "VScrollAction") || HasProp(lider, "HScrollAction")
                        return lider
            }
        }
        return 0
    }

    /**
     * @desc Zunifikowany router HWND. Wspina się po drzewie logiki (ParentCtrl) i panelach (DummyCtrl).
     * @param {GuiCtrl|Integer} obj - Kontrolka startowa lub HWND.
     * @param {String} [wymaganaWlasciwosc=""] - Zatrzymuje wspinaczkę i zwraca obiekt, gdy znajdzie podaną właściwość.
     * @param {SilnikGUI} [limitSilnik=0] - Zatrzymuje wspinaczkę paneli na podanym silniku (używane do Hover/Focus).
     * @return {GuiCtrl|Integer} - Znaleziony obiekt kontrolki lub pierwotny HWND.
     */
    static RozwiazKontrolke(obj, wymaganaWlasciwosc := "", limitSilnik := 0) {
        try {
            ctrl := IsInteger(obj) ? GuiCtrlFromHwnd(obj) : obj
            h := IsInteger(obj) ? obj : (ctrl ? ctrl.Hwnd : 0)

            curr := ctrl
            while curr {
                if (wymaganaWlasciwosc != "" && HasProp(curr, wymaganaWlasciwosc))
                    return curr
                if !HasProp(curr, "ParentCtrl")
                    break
                curr := curr.ParentCtrl
            }

            if (wymaganaWlasciwosc != "")
                return 0

            if (limitSilnik) {
                currG := curr ? curr.Gui : GuiFromHwnd(h)
                while currG && HasProp(currG, "Silnik") {
                    if HasProp(currG.Silnik, "DummyCtrl") && IsObject(currG.Silnik.DummyCtrl) {
                        dGui := currG.Silnik.DummyCtrl.Gui
                        if (dGui == limitSilnik.GuiObj || dGui == limitSilnik.Stan.ChildGui)
                            return currG.Silnik.DummyCtrl.Hwnd
                    }
                    parentHwnd := DllCall("GetAncestor", "Ptr", currG.Hwnd, "UInt", 1, "Ptr")
                    currG := parentHwnd ? GuiFromHwnd(parentHwnd) : 0
                }
            }
            return curr ? curr : h
        }
        return obj
    }

    /**
     * Centralny zarządca globalnego haka myszy (WH_MOUSE_LL). Włącza hak tylko gdy jest to wymagane.
     */
    static AktualizujHooka() {
        potrzebny := SilnikGUI.Statics.StanMButtonScroll.Aktywny || (SilnikGUI.WatchdogiClick.Length > 0)
        if (potrzebny && !SilnikGUI.Statics.GlobalMouseHook) {
            if (!SilnikGUI.Statics.GlobalHookCallback)
                SilnikGUI.Statics.GlobalHookCallback := CallbackCreate(ObjBindMethod(SilnikGUI, "CentralMouseHookProc"), "Fast", 3)
            SilnikGUI.Statics.GlobalMouseHook := DllCall("SetWindowsHookEx", "Int", 14, "Ptr", SilnikGUI.Statics.GlobalHookCallback, "Ptr", DllCall("GetModuleHandle", "Ptr", 0, "Ptr"), "UInt", 0, "Ptr")
        } else if (!potrzebny && SilnikGUI.Statics.GlobalMouseHook) {
            DllCall("UnhookWindowsHookEx", "Ptr", SilnikGUI.Statics.GlobalMouseHook)
            SilnikGUI.Statics.GlobalMouseHook := 0
        }
    }

    /**
     * Centralny, niskopoziomowy hak systemowy myszy (WH_MOUSE_LL).
     * Routing zdarzeń dla MButtonScroll i Watchdogów popupów. 100% DRY.
     * @param {Integer} nCode - Kod akcji przekazywany przez Windows.
     * @param {Integer} wParam - Identyfikator komunikatu myszy (np. WM_MBUTTONUP).
     * @param {Integer} lParam - Wskaźnik do struktury MSLLHOOKSTRUCT.
     * @returns {Integer} - 1 (połknięcie sygnału) lub wywołanie CallNextHookEx.
     */
    static CentralMouseHookProc(nCode, wParam, lParam) {
        if (nCode >= 0) {
            ; --- 1. MButton Scroll ---
            st := SilnikGUI.Statics.StanMButtonScroll
            if (st.Aktywny) {
                msg := wParam
                if (msg == 0x0208) { ; WM_MBUTTONUP
                    if (!st.TrybToggle) {
                        if (A_TickCount - st.TickStart < st.Opcje.MBuToggleT) {
                            st.TrybToggle := true
                            return 1 ; POŁKNIJ: System myśli, że MButton wciąż wciśnięty (SetCapture trwa)
                        } else
                            SetTimer(SilnikGUI.Statics.ZakonczMButtonScrollObj, -1) ; DEFER: Ochrona przed desynchronizacją DWM
                    }
                } else if (st.TrybToggle && (msg == 0x0207)) { ; 0x0201: WM_LBUTTONDOWN, 0x0204: WM_RBUTTONDOWN, 0x0207: WM_MBUTTONDOWN, 0x020B: WM_XBUTTONDOWN
                    SetTimer(SilnikGUI.Statics.ZakonczMButtonScrollObj, -1) ; DEFER: Zakończenie Toggle poza wątkiem Hooka
                    return 1 ; POŁKNIJ: Ignoruj każde kliknięcie zakańczające w systemie
                }
            }

            ; --- 2. Watchdog Popupów ---
            if (SilnikGUI.WatchdogiClick.Length > 0 && (wParam == 0x0201 || wParam == 0x0204 || wParam == 0x0207 || wParam == 0x020B || wParam == 0x00A1 || wParam == 0x00A4 || wParam == 0x00A7 || wParam == 0x00AB)) {
                hCtrl := SilnikGUI.GetRealHwndUnderMouse()
                hRoot := DllCall("GetAncestor", "Ptr", hCtrl, "UInt", 2, "Ptr")
                lider := SilnikGUI.RozwiazKontrolke(hCtrl)
                lHwnd := IsObject(lider) ? lider.Hwnd : lider

                kopia := []
                for wd in SilnikGUI.WatchdogiClick
                    kopia.Push(wd)

                for wd in kopia {
                    safe := false
                    for h in wd.Dozwolone {
                        if (h && (h == hCtrl || h == hRoot || h == lHwnd)) {
                            safe := true
                            break
                        }
                    }
                    if (!safe)
                        SetTimer(wd.OnExit, -1) ; Asynchroniczne zamknięcie bez blokady
                }
            }
        }
        return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wParam, "Ptr", lParam)
    }

    /**
     * Główna asynchroniczna pętla autoscrolla (Timer).
     * Odpowiada za odczyt dystansu kursora, rotację grafiki krzyżyka, aplikowanie tłumienia predykcyjnego i wstrzykiwanie wektorów.
     */
    static PetlaMButtonScroll() {
        st := SilnikGUI.Statics.StanMButtonScroll
        if !st.Aktywny
            return SetTimer(SilnikGUI.Statics.PetlaMButtonScrollObj, 0)


        DllCall("GetCursorPos", "Ptr", pt := Buffer(8))
        cx := NumGet(pt, 0, "Int"), cy := NumGet(pt, 4, "Int")

        dx := cx - st.StartX, dy := cy - st.StartY
        dist := Sqrt(dx ** 2 + dy ** 2)

        clipDir := ""
        if (st.CanX && !st.CanY) {
            curId := 32644 ; Wymuś poziom
            if (dist > st.Opcje.MBuDeadZone)
                clipDir := (dx > 0) ? 3 : ((dx < 0) ? 7 : "")
        } else if (st.CanY && !st.CanX) {
            curId := 32645 ; Wymuś pion
            if (dist > st.Opcje.MBuDeadZone)
                clipDir := (dy > 0) ? 5 : ((dy < 0) ? 1 : "")
        } else {
            curId := 32646, clipDir := 0 ; Środek
            if (dist > st.Opcje.MBuDeadZone) {
                if (dx == 0) { ; Ochrona przed dzieleniem przez zero
                    angle := (dy > 0) ? 90 : 270
                } else {
                    angle := ATan(dy / dx) * (180 / 3.141592653589793)
                    (dx < 0) ? angle += 180 : ((dy < 0) ? angle += 360 : 0)
                }

                if (angle >= 337.5 || angle < 22.5) {
                    curId := 32644, clipDir := 3 ; R
                } else if (angle >= 22.5 && angle < 67.5) {
                    curId := 32642, clipDir := 4 ; RD
                } else if (angle >= 67.5 && angle < 112.5) {
                    curId := 32645, clipDir := 5 ; D
                } else if (angle >= 112.5 && angle < 157.5) {
                    curId := 32643, clipDir := 6 ; LD
                } else if (angle >= 157.5 && angle < 202.5) {
                    curId := 32644, clipDir := 7 ; L
                } else if (angle >= 202.5 && angle < 247.5) {
                    curId := 32642, clipDir := 8 ; LU
                } else if (angle >= 247.5 && angle < 292.5) {
                    curId := 32645, clipDir := 1 ; U
                } else {
                    curId := 32643, clipDir := 2 ; RU
                }
            }
        }

        maxDist := Max(Abs(dx), Abs(dy))
        maxDistSqrt := Sqrt(dx * dx + dy * dy)
        maxDist := ((clipDir != "") && (clipDir & 1)) ? maxDist : maxDistSqrt ; argument nieparzystkości z modulo
        targetScale := st.Opcje.MBCurScale ? Round((1.0 + Min(1.0, maxDist / (A_ScreenHeight / 2))) * 3) / 3 : (clipDir > 0 ? 1.5 : 1)

        if (st.LastCurId != curId || st.LastClipDir != clipDir || st.LastScale != targetScale) {
            if (st.Fake)
                st.Fake.Destroy()
            hCursor := DllCall("LoadCursor", "Ptr", 0, "UInt", curId, "Ptr")
            st.Fake := SilnikGUI.FakeCur(st.Instancja.GuiObj.Hwnd, hCursor, clipDir, targetScale)
            st.LastCurId := curId
            st.LastClipDir := clipDir
            st.LastScale := targetScale
        }

        st.Fake.Move(cx, cy)
        DllCall("SetCursor", "Ptr", 0)

        if (dist <= st.Opcje.MBuDeadZone) {
            st.OstatnieVx := 0, st.OstatnieVy := 0
            return
        }

        vx := dx * st.Opcje.MBuCz
        vy := dy * st.Opcje.MBuCz

        ; Hamowanie predykcyjne
        Silnik := st.Instancja
        Silnik.Stan.ChildGui.GetPos(&cX, &cY)
        pFaktor := st.Opcje.MBuProgFakt

        if (Silnik.Stan.VBar && vy != 0) {
            maxScroll := Max(0, Silnik.Stan.VBar.LastGeo.Content - Silnik.Stan.VBar.LastGeo.View)
            progH := st.Opcje.MBuProgHam
            if (maxScroll < progH * pFaktor)
                progH := Max(1, progH * (maxScroll / (progH * pFaktor)))
            distToWall := (vy > 0) ? (maxScroll + cY) : -cY
            if (distToWall < progH)
                vy *= Max(0.05, distToWall / progH)
        } else {
            vy := 0
        }

        if (Silnik.Stan.HBar && vx != 0) {
            maxScroll := Max(0, Silnik.Stan.HBar.LastGeo.Content - Silnik.Stan.HBar.LastGeo.View)
            progW := st.Opcje.MBuProgHam
            if (maxScroll < progW * pFaktor)
                progW := Max(1, progW * (maxScroll / (progW * pFaktor)))
            distToWall := (vx > 0) ? (maxScroll + cX) : -cX
            if (distToWall < progW)
                vx *= Max(0.05, distToWall / progW)
        } else {
            vx := 0
        }

        st.OstatnieVx := vx, st.OstatnieVy := vy
        st.AccumX += vx, st.AccumY += vy
        stepX := Round(st.AccumX), stepY := Round(st.AccumY)

        if (stepX != 0 || stepY != 0) {
            st.AccumX -= stepX, st.AccumY -= stepY
            bar := Silnik.Stan.VBar ? Silnik.Stan.VBar : Silnik.Stan.HBar
            bar.Kinetyka.TrybFocus := false
            bar.PrzewinObszar(-stepX, -stepY)
        }
    }

    /**
     * Przerywa i czyści trwający proces autoscrollowania.
     * Odłącza haki, uwalnia mysz, przekazuje resztkowy wektor kinetyczny paskom i resetuje sprzętowy cache kursora w DWM.
     */
    static ZakonczMButtonScroll() {
        st := SilnikGUI.Statics.StanMButtonScroll
        if !st.Aktywny
            return

        wasToggle := st.TrybToggle
        st.Aktywny := false
        DllCall("ReleaseCapture")
        SilnikGUI.AktualizujHooka()
        if (wasToggle)
            DllCall("mouse_event", "UInt", 0x0040, "UInt", 0, "UInt", 0, "UInt", 0, "UPtr", 0) ; Wymuś MButton UP w systemie
        ; Usunięto destruktywny CallbackFree - zabezpieczenie łańcucha systemowego
        if SilnikGUI.Statics.PetlaMButtonScrollObj
            SetTimer(SilnikGUI.Statics.PetlaMButtonScrollObj, 0)

        if (st.Fake) {
            st.Fake.Destroy()
            st.Fake := 0
        }

        ; Fuzja kinetyczna po zatrzymaniu (odwrócony znak wektora dla poprawnego kierunku wybiegu)
        if (Abs(st.OstatnieVx) > 2 || Abs(st.OstatnieVy) > 2) {
            (st.Instancja.Stan.VBar) && (st.Instancja.Stan.VBar.Kinetyka.TrybFocus := false, st.Instancja.Stan.VBar.DodajPed(-st.OstatnieVy * st.Opcje.MBuWyb, st.Opcje.MBuMaxSpeed))
            (st.Instancja.Stan.HBar) && (st.Instancja.Stan.HBar.Kinetyka.TrybFocus := false, st.Instancja.Stan.HBar.DodajPed(-st.OstatnieVx * st.Opcje.MBuWyb, st.Opcje.MBuMaxSpeed))
        }

        DllCall("GetCursorPos", "Ptr", pt := Buffer(8))
        x := NumGet(pt, 0, "Int"), y := NumGet(pt, 4, "Int")
        DllCall("SetCursorPos", "Int", x, "Int", y + 1)
        DllCall("SetCursorPos", "Int", x, "Int", y) ; Sprzętowe wymuszenie prawdziwego WM_SETCURSOR z jądra OS
    }

    /**
     * Sprawdza, czy element (Kontrolka lub GUI) może przyjąć interakcję.
     * Warunki: Okno aktywne, Okno niezablokowane, Brak aktywnego Popupu (chyba że to my).
     * @param {GuiCtrl|Gui} obj - Obiekt do sprawdzenia.
     */
    static CzyMoznaInterakcja(obj) {
        try {
            targetGui := HasProp(obj, "Gui") ? obj.Gui : obj
            ; [FIX] Pobierz okno nadrzędne (Root), bo ChildGui nigdy nie jest "Active" w oczach systemu
            hRoot := DllCall("GetAncestor", "Ptr", targetGui.Hwnd, "UInt", 2, "Ptr") ; GA_ROOT = 2

            if !WinActive(hRoot) || (WinGetStyle(targetGui.Hwnd) & 0x8000000) || (HasProp(targetGui, "PopupActive") && targetGui.PopupActive)
                return false
            return true
        }
        return false
    }

    /**
     * Waliduje zawartość pola edycji w czasie rzeczywistym (Float).
     */
    static WalidujFloat(DoKorekty, Info := "", pokazBlad := true, czasSekundy := 4.0) {
        tekst := DoKorekty.Value
        czysty := RegExReplace(tekst, "[^0-9,.]")
        if (RegExMatch(czysty, "[.,]", &match)) {
            prefix := SubStr(czysty, 1, match.Pos)
            suffix := SubStr(czysty, match.Pos + 1)
            suffix := StrReplace(StrReplace(suffix, ".", ""), ",", "")
            czysty := prefix . suffix
        }
        if (tekst != czysty) {
            pos := SendMessage(0xB0, 0, 0, DoKorekty)
            cursorPos := pos & 0xFFFF
            DoKorekty.Value := czysty
            newPos := Max(0, cursorPos - 1)
            SendMessage(0xB1, newPos, newPos, DoKorekty)
            if (pokazBlad) {
                SilnikGUI.PokazDymekBledu(DoKorekty, "W tym polu możesz wpisywać tylko cyfry`noraz jeden znak separatora (kropka/przecinek).", , Integer(czasSekundy * 1000))
                DoKorekty.OnEvent("LoseFocus", (*) => ToolTip(, , , 10))
            }
        }
    }

    /**
     * Waliduje zawartość pola edycji (Integer).
     */
    static WalidujInt(DoKorekty, Info := "", pokazBlad := true, czasSekundy := 1.5) {
        tekst := DoKorekty.Value
        czysty := RegExReplace(tekst, "[^0-9]")
        if (tekst != czysty) {
            pos := SendMessage(0xB0, 0, 0, DoKorekty)
            cursorPos := pos & 0xFFFF
            DoKorekty.Value := czysty
            newPos := Max(0, cursorPos - 1)
            SendMessage(0xB1, newPos, newPos, DoKorekty)
            if (pokazBlad) {
                SilnikGUI.PokazDymekBledu(DoKorekty, "W tym polu możesz wpisywać tylko cyfry.", , Integer(czasSekundy * 1000))
                DoKorekty.OnEvent("LoseFocus", (*) => ToolTip(, , , 10))
            }
        }
    }

    /**
     * Oblicza nową wartość z uwzględnieniem limitów i detekcją przekroczenia zakresu.
     * @param {Number} start - Wartość początkowa.
     * @param {Number} delta - Zmiana (kierunek * krok).
     * @param {Number} minV - Minimum (lub "" jeśli brak).
     * @param {Number} maxV - Maksimum (lub "" jeśli brak).
     * @returns {Object} {V: Number, Flash: Boolean}
     */
    static ObliczLimit(start, delta, minV, maxV) {
        raw := start + delta
        val := raw
        (minV != "") && val := Max(val, minV)
        (maxV != "") && val := Min(val, maxV)
        return { V: val, Flash: (val != raw) }
    }

    /**
     * Uniwersalny strażnik wyjścia (zastępuje Watchdog i Pilnuj).
     * @param {Func} OnExit - Funkcja wywoływana po wykryciu wyjścia/kliknięcia poza.
     * @param {Array} Dozwolone - Lista HWND, które są bezpieczne.
     * @param {String} [Tryb="Click"] - "Click" (zamknij po kliknięciu poza) lub "Hover" (zamknij po zjechaniu).
     * @param {Func} [OnLoop=0] - Opcjonalna funkcja wykonywana w pętli, gdy stan jest bezpieczny.
     * @param {Integer} [DelayOFF=0] - Czas opóźnienia wygaszania (Pending Kill).
     * @returns {Func} - Zwraca referencję do timera (aby można go było zatrzymać ręcznie).
     */
    static MonitorujWyjscie(OnExit, Dozwolone, Tryb := "Click", OnLoop := 0, DelayOFF := 0) {
        if (Tryb == "Click") {
            wd := { OnExit: OnExit, Dozwolone: Dozwolone }
            SilnikGUI.WatchdogiClick.Push(wd)
            SilnikGUI.AktualizujHooka()

            UsunClick(*) {
                for i, item in SilnikGUI.WatchdogiClick {
                    if (item == wd) {
                        SilnikGUI.WatchdogiClick.RemoveAt(i)
                        break
                    }
                }
                SilnikGUI.AktualizujHooka()
            }
            return UsunClick
        }

        pendingKill := 0
        Check() {
            MouseGetPos(, , &win)
            ctrl := SilnikGUI.GetRealHwndUnderMouse()
            lider := SilnikGUI.RozwiazKontrolke(ctrl)
            lHwnd := IsObject(lider) ? lider.Hwnd : lider

            safe := false
            for h in Dozwolone
                if (h && (h == win || h == ctrl || h == lHwnd)) {
                    safe := true
                    break
                }

            if (safe) {
                if (pendingKill)
                    SetTimer(Wygas, 0), pendingKill := 0
                return (OnLoop && OnLoop(0))
            }

            if (DelayOFF > 0 && !pendingKill) {
                pendingKill := 1
                SetTimer(Wygas, -DelayOFF)
            } else if (!pendingKill) {
                SetTimer(Check, 0), OnExit()
                return
            }

            if (pendingKill)
                return (OnLoop && OnLoop(1))
        }
        Wygas() => (SetTimer(Check, 0), OnExit())
        UsunHover(*) => (SetTimer(Check, 0), (pendingKill && SetTimer(Wygas, 0)))
        SetTimer(Check, SilnikGUI.TickRate)
        return UsunHover
    }

    /**
     * Prekalkulacja układu (Align) w celu optymalizacji pętli pozycjonowania.
     */
    static ParsujAlign(Align) {
        instrukcje := []
        pos := 1
        while RegExMatch(Align, "i)([+-m])?(Left|Right|Up|Down|CenterX|CenterY)(?:([+-]\d+))?", &m, pos) {
            pre := StrLower(m[1]), dir := StrLower(m[2]), suf := (m[3] != "") ? Integer(m[3]) : 0
            instrukcje.Push({ pre: pre, dir: dir, suf: suf })
            pos := m.Pos + m.Len
        }
        return instrukcje
    }

    /**
     * Prekalkulacja opcji ruchu (DTO) w celu optymalizacji pętli pozycjonowania.
     */
    static ParsujMove(MoveStr) {
        return {
            XMTrack: InStr(MoveStr, "XMTrack") > 0,
            YMTrack: InStr(MoveStr, "YMTrack") > 0,
            XATrack: InStr(MoveStr, "XATrack") > 0,
            YATrack: InStr(MoveStr, "YATrack") > 0,
            NoClampX: InStr(MoveStr, "NoClampX") > 0,
            XStop: InStr(MoveStr, "XStop") > 0,
            YStop: InStr(MoveStr, "YStop") > 0
        }
    }

    /**
     * Oblicza pozycję popupu względem kotwicy (Smart Positioning).
     * Obsługuje automatyczne odbicie w pionie (Flip) i trzymanie się ekranu w poziomie (Clamp).
     * @param {Object} KotwicaObj - Obiekt {x,y,w,h} reprezentujący granice kotwicy.
     * @param {Integer} w - Szerokość popupu.
     * @param {Integer} h - Wysokość popupu.
     * @param {Array} ParsedAlign - Ustrukturyzowana tablica układu wygenerowana przez ParsujAlign.
     * @param {Object} ParsedMove - Obiekt flag (DTO) wygenerowany przez ParsujMove.
     * @param {Integer} [OffY=0] - Odstęp pionowy. Przy odbiciu (Flip) używana jest połowa tej wartości.
     * @param {Integer} [OffX=0] - Odstęp poziomy.
     * @param {Object} [MonArea=0] - Obiekt granic obszaru roboczego monitora {L, T, R, B}.
     * @returns {Object} - Obiekt {x: Integer, y: Integer} z finalną pozycją.
     */
    static DopasujDoKotwicy(trybStr, KotwicaObj, w, h, ParsedAlign, ParsedMove, OffY := 0, OffX := 0, MonArea := 0) {
        kx := KotwicaObj.x, ky := KotwicaObj.y, kw := KotwicaObj.w, kh := KotwicaObj.h
        x := kx + (kw - w) / 2, y := ky + (kh - h) / 2
        effKy := ky, effKh := kh ; Oś obrotu dla flipa
        if (trybStr == "Mouse") {
            x := kx, y := ky
            effKy := ky, effKh := 0
        }
        sufX := 0, sufY := 0
        defX := false, defY := false

        for m in ParsedAlign {
            pre := m.pre, dir := m.dir, suf := m.suf
            isX := (dir == "left" || dir == "right" || dir == "centerx")
            isY := (dir == "up" || dir == "down" || dir == "centery")
            (isX) && defX := true
            (isY) && defY := true

            switch trybStr {
                case "Anchor":
                    if (isX) {
                        if (pre == "m") {
                            if !IsSet(mX) { ; Pobierz kursor tylko gdy to konieczne
                                pt := Buffer(8), DllCall("GetCursorPos", "Ptr", pt)
                                mX := NumGet(pt, 0, "Int"), mY := NumGet(pt, 4, "Int")
                            }
                            x := (dir == "left") ? (mX - w) : ((dir == "right") ? mX : (mX - w / 2))
                        } else if (dir == "centerx") {
                            x := kx + (kw - w) / 2
                        } else {
                            (pre == "") && pre := (dir == "left") ? "-" : "+"
                            x := (dir == "left") ? ((pre == "-") ? (kx - w) : kx) : ((pre == "-") ? (kx + kw - w) : (kx + kw))
                        }
                        sufX := suf
                    } else if (isY) {
                        if (pre == "m") {
                            if !IsSet(mX) {
                                pt := Buffer(8), DllCall("GetCursorPos", "Ptr", pt)
                                mX := NumGet(pt, 0, "Int"), mY := NumGet(pt, 4, "Int")
                            }
                            effKy := mY, effKh := 0
                            y := (dir == "up") ? (mY - h) : ((dir == "down") ? mY : (mY - h / 2))
                        } else if (dir == "centery") {
                            y := ky + (kh - h) / 2
                        } else {
                            (pre == "") && pre := (dir == "up") ? "-" : "+"
                            y := (dir == "up") ? ((pre == "-") ? (ky - h) : ky) : ((pre == "-") ? (ky + kh - h) : (ky + kh))
                        }
                        sufY := suf
                    }
                case "Mouse":
                    if (isX) {
                        x := (dir == "left") ? (kx - w) : ((dir == "right") ? kx : (kx - w / 2))
                        sufX := suf
                    } else if (isY) {
                        y := (dir == "up") ? (ky - h) : ((dir == "down") ? ky : (ky - h / 2))
                        sufY := suf
                    }
                case "Screen":
                    if (isX) {
                        x := (dir == "left") ? kx : ((dir == "right") ? (kx + kw - w) : (kx + (kw - w) / 2))
                        sufX := suf
                    } else if (isY) {
                        y := (dir == "up") ? ky : ((dir == "down") ? (ky + kh - h) : (ky + (kh - h) / 2))
                        sufY := suf
                    }
            }
        }

        if (trybStr == "Mouse") {
            (defX) && OffX := 0
            (defY) && OffY := 0
        }

        x += sufX + OffX, y += sufY + OffY

        if (MonArea) {
            if (trybStr != "Screen") {
                if (y + h > MonArea.B)
                    y := effKy - h - sufY - Integer(OffY / 2)
                else if (y < MonArea.T)
                    y := effKy + effKh - sufY + Integer(OffY / 2)

                if !ParsedMove.NoClampX
                    x := Min(Max(x, MonArea.L), MonArea.R - w)
            }
        }
        return { x: x, y: y }
    }

    /**
     * Tworzy atrapę kursora (Layered Window) z obsługą Alpha i Hotspot.
     * @param {Integer} hOwner - Uchwyt okna nadrzędnego.
     * @param {Integer} [hCursor=0] - Uchwyt kursora do skopiowania (domyślnie aktualny kursor).
     * @param {String} [clipDir=""] - Kierunek przycinania: "N", "NE", "E", "SE", "S", "SW", "W", "NW" lub "" (brak).
     * @param {Float} [scale=1.0] - Skala rozmiru kursora (domyślnie 1.0).
     * @returns {Object} - Kontroler {Move(x,y), Hide(), Destroy()}.
     */
    static FakeCur(hOwner, hCursor := 0, clipDir := "", scale := 1.0) {
        VCursor := Gui("-Caption +ToolWindow +AlwaysOnTop +E0x20 +E0x80000 -DPIScale +Owner" . hOwner) ;

        if (!hCursor) {
            ci := Buffer(24, 0), NumPut("Int", 24, ci), DllCall("GetCursorInfo", "Ptr", ci)
            hCursor := NumGet(ci, 8, "Ptr")
        }

        ii := Buffer(32, 0), DllCall("GetIconInfo", "Ptr", hCursor, "Ptr", ii)
        xHot := NumGet(ii, 4, "UInt"), yHot := NumGet(ii, 8, "UInt")

        hBmMask := NumGet(ii, 12 + (A_PtrSize = 8 ? 4 : 0), "Ptr")
        hBmColor := NumGet(ii, 12 + (A_PtrSize = 8 ? 4 : 0) + A_PtrSize, "Ptr")

        w := 32, h := 32
        bm := Buffer(32, 0)
        if (hBmColor) {
            DllCall("GetObject", "Ptr", hBmColor, "Int", 32, "Ptr", bm)
            w := NumGet(bm, 4, "Int"), h := NumGet(bm, 8, "Int")
        } else if (hBmMask) {
            DllCall("GetObject", "Ptr", hBmMask, "Int", 32, "Ptr", bm)
            w := NumGet(bm, 4, "Int"), h := NumGet(bm, 8, "Int") // 2
        }

        (hBmMask) && DllCall("DeleteObject", "Ptr", hBmMask)
        (hBmColor) && DllCall("DeleteObject", "Ptr", hBmColor)

        s := scale
        sW := Round(w * s), sH := Round(h * s)
        sXHot := Round(xHot * s), sYHot := Round(yHot * s)

        hDC := DllCall("GetDC", "Ptr", 0, "Ptr"), hMemDC := DllCall("CreateCompatibleDC", "Ptr", hDC, "Ptr")
        bi := Buffer(40, 0), NumPut("UInt", 40, bi, 0), NumPut("Int", sW, bi, 4), NumPut("Int", sH, bi, 8), NumPut("UShort", 1, bi, 12), NumPut("UShort", 32, bi, 14)
        hDIB := DllCall("CreateDIBSection", "Ptr", hDC, "Ptr", bi, "UInt", 0, "Ptr*", &pBits := 0, "Ptr", 0, "UInt", 0, "Ptr")
        hOld := DllCall("SelectObject", "Ptr", hMemDC, "Ptr", hDIB)

        if (clipDir != "") {
            cX := 0, cY := 0, cW := sW, cH := sH
            if (clipDir == 1) ; N
                cH := sYHot
            else if (clipDir == 5) ; S
                cY := sYHot, cH := sH - sYHot
            else if (clipDir == 7) ; W
                cW := sXHot
            else if (clipDir == 3) ; E
                cX := sXHot, cW := sW - sXHot
            else if (clipDir == 8) ; NW
                cW := sXHot, cH := sYHot
            else if (clipDir == 2) ; NE
                cX := sXHot, cW := sW - sXHot, cH := sYHot
            else if (clipDir == 6) ; SW
                cY := sYHot, cH := sH - sYHot, cW := sXHot
            else if (clipDir == 4) ; SE
                cX := sXHot, cY := sYHot, cW := sW - sXHot, cH := sH - sYHot

            DllCall("IntersectClipRect", "Ptr", hMemDC, "Int", cX, "Int", cY, "Int", cX + cW, "Int", cY + cH)
        }

        DllCall("DrawIconEx", "Ptr", hMemDC, "Int", 0, "Int", 0, "Ptr", hCursor, "Int", sW, "Int", sH, "UInt", 0, "Ptr", 0, "UInt", 3)

        pAlpha := WinGetTransparent(DllCall("GetAncestor", "Ptr", hOwner, "UInt", 2, "Ptr"))
        alphaVal := IsNumber(pAlpha) ? pAlpha : 255

        ptSrc := Buffer(8, 0), size := Buffer(8, 0), NumPut("Int", sW, size, 0), NumPut("Int", sH, size, 4)
        blend := Buffer(4, 0), NumPut("UChar", alphaVal, blend, 2), NumPut("UChar", 1, blend, 3)
        DllCall("UpdateLayeredWindow", "Ptr", VCursor.Hwnd, "Ptr", hDC, "Ptr", 0, "Ptr", size, "Ptr", hMemDC, "Ptr", ptSrc, "UInt", 0, "Ptr", blend, "UInt", 2)

        DllCall("SelectObject", "Ptr", hMemDC, "Ptr", hOld), DllCall("DeleteObject", "Ptr", hDIB), DllCall("DeleteDC", "Ptr", hMemDC), DllCall("ReleaseDC", "Ptr", 0, "Ptr", hDC)

        return { Move: (_, x, y) => VCursor.Show("NA x" . (x - sXHot) . " y" . (y - sYHot) . " w" . sW . " h" . sH), Hide: (*) => VCursor.Hide(), Destroy: (*) => VCursor.Destroy(), Hwnd: VCursor.Hwnd, SkipMonitor: true }
    }
}

Class ExWinAndPopups extends Logika {
    /**
     *      
     * Universal tooltip function integrated with SilnikGUI theme.
     * Combines static display, mouse tracking, and control watchdog.
     * @param {String} [tresc=""] - Text to display. Empty string kills tooltip. `n`n=empty line, `n..`n=1px gap, `n.[X].`n=X px gap.
     * @param {Object} [opcje] - Optional config object with parameters:
     * - [ON: 1] {Integer} - Allows rendering (0 disables). Empty string (kill tooltip) always works.
     * - [czas: 0] {Number} - Display time in ms (default 0 = no limit).
     * - [trybPozycji: "Mouse"] {Object|String} - "Mouse", "Screen", or Object. REQUIRED for Anchor: pass the GUI control object (e.g. trybPozycji: myControl). {SkipMonitor:true} = tracking.
     * - [Align: "+Down"] {String} - Declarative layout: "[+-m]Direction[Offset]". [+-]: window relative, [m]: mouse relative. Direction: e.g. Left, CenterX.
     * - [Move: ""] {String} - Movement flags: "XMTrack"/"YMTrack" (mouse), "XStop"/"YStop" (freeze), "XATrack"/"YATrack" (anchor).
     * - [DelayON: 0] {Integer} - Delay before showing tooltip (ms).
     * - [DelayOFF: 0] {Integer} - Delay before killing tooltip (ms).
     * - [kolorTla: ""] {String} - Background color.
     * - [kolorRamki: ""] {String} - Border color.
     * - [kolorTekstu: ""] {String} - Text color.
     * - [MargPion: 4] {Integer} - Vertical margin (px).
     * - [MargPoz: 8] {Integer} - Horizontal margin (px).
     * - [rozmiarCzcionki: SilnikGUI.Statics.GlobFont.Size] {Integer} - Font size (pt).
     * - [czyPogrubione: 0] {Integer} - Bold font (0/1).
     * - [Transparent: 0.0] {Float} - Tooltip transparency (0.0 - 1.0).
     * - [TransClick: ""] {Boolean|String} - Click-through mode (true/false, "" = auto by mode).
     * 
     * @example Bind to hover: `myControl.HoverAction := (*) => SilnikGUI.CustomTooltip("Text", {trybPozycji: myControl})`
     * @note Lambda `(*)` is required to absorb default arguments passed by the SilnikGUI engine.
     */
    static CustomTooltip(tresc := "", opcje?) {
        opcje := Utils.MergeOptions(opcje?, { Align: "+Down", Move: "", ON: 1, czas: 0, DelayON: this.TipDelayON, DelayOFF: this.TipDelayOFF, trybPozycji: "Mouse", kolorTla: "", kolorTekstu: "", kolorRamki: "", MargPion: 4, MargPoz: 8, FontSize: 10, FontOpt: "", rozmiarCzcionki: SilnikGUI.Statics.GlobFont.Size, czyPogrubione: 0, Transparent: "", TransClick: "" })
        Align := opcje.Align, Move := opcje.Move, ON := opcje.ON, czas := opcje.czas, DelayON := opcje.DelayON, DelayOFF := opcje.DelayOFF, trybPozycji := opcje.trybPozycji, kolorTla := opcje.kolorTla, kolorTekstu := opcje.kolorTekstu, kolorRamki := opcje.kolorRamki, MargPion := opcje.MargPion, MargPoz := opcje.MargPoz, FontSize := opcje.FontSize, FontOpt := opcje.FontOpt, rozmiarCzcionki := opcje.rozmiarCzcionki, czyPogrubione := opcje.czyPogrubione, Transparent := opcje.Transparent, TransClick := opcje.TransClick

        FontMulti := SilnikGUI.Statics.TotalScale
        Skala := (A_ScreenDPI / 96) * FontMulti

        ; [ADAPTER] Kompatybilność wsteczna + bezpieczne kierowanie typów (Mouse, Screen, Anchor)
        trybStr := (trybPozycji == 0 || trybPozycji == "0" || trybPozycji == "Mouse") ? "Mouse" : (IsObject(trybPozycji) ? "Anchor" : "Screen")

        if (trybStr == "Mouse") {
            (Align == "+Down") && Align := ""
            (Move == "") && Move := "XMTrack YMTrack"
        } else if (trybStr == "Anchor") {
            (!RegExMatch(Move, "i)X[MA]Track|XStop")) && Move .= " XATrack"
            (!RegExMatch(Move, "i)Y[MA]Track|YStop")) && Move .= " YATrack"
        }
        ParsedMove := SilnikGUI.ParsujMove(Move)
        igX := (trybStr != "Screen") && ParsedMove.XMTrack
        igY := (trybStr != "Screen") && ParsedMove.YMTrack

        if (!ON && tresc != "")
            return

        static GuiTip := 0
        static TimerZamykania := 0
        static TimerSledzenia := 0
        static TimerOpoznienia := 0
        static TempMonitor := 0
        static OstatniaTresc := "", OstatniKolorTla := "", OstatniKolorTekstu := "", OstatniKolorRamki := "", OstatniMargPion := "", OstatniMargPoz := "", OstatniRozmiar := "", OstatniePogrubienie := "", OstatniTryb := "", OstatnieIgX := 0, OstatnieIgY := 0, OstatniTransparent := 1.0, OstatniTransClick := ""
        static OstatniSilnikTooltipa := 0
        static OstatniCel := 0
        StareGui := 0

        if (TimerZamykania)
            SetTimer(TimerZamykania, 0), TimerZamykania := 0
        if (TimerSledzenia)
            TimerSledzenia(), TimerSledzenia := 0
        if (TimerOpoznienia)
            SetTimer(TimerOpoznienia, 0), TimerOpoznienia := 0
        if (TempMonitor)
            TempMonitor(), TempMonitor := 0

        hCel := 0
        if (trybStr == "Anchor" && HasProp(trybPozycji, "Hwnd")) {
            try hCel := trybPozycji.Hwnd
            catch { ; Przechwytuje błąd zniszczonej kontrolki (async delay)
                if (tresc != "")
                    return
            }
        }

        ; Pobierz uchwyt okna nadrzędnego (GA_ROOT = 2) dla relacji +Owner
        hOwner := hCel ? DllCall("GetAncestor", "Ptr", hCel, "UInt", 2, "Ptr") : 0

        ; [FIX] Dziedziczenie przezroczystości z okna rodzica
        if (Transparent == "") {
            pAlpha := hOwner ? WinGetTransparent(hOwner) : ""
            Transparent := IsNumber(pAlpha) ? (1.0 - (pAlpha / 255)) : 0.0
        }
        Transparent := 1.0 - Transparent
        ; Obiektowa kotwica (Fallback: 1. AnchorCtrl, 2. Ramka, 3. Sam obiekt)
        Anchor := (trybStr == "Anchor" && HasProp(trybPozycji, "AnchorCtrl")) ? trybPozycji.AnchorCtrl : ((trybStr == "Anchor" && HasProp(trybPozycji, "Ramka")) ? trybPozycji.Ramka : trybPozycji)

        ; [BUILDER] Przygotowuje czyste dane (Granice Kotwicy i Monitora) dla funkcji matematycznej
        GetKObj() {
            MonitorGetWorkArea(MonitorGetPrimary(), &mL, &mT, &mR, &mB)
            M := { L: mL, T: mT, R: mR, B: mB }
            K := { x: 0, y: 0, w: 0, h: 0 }

            if (trybStr == "Screen") {
                K.x := mL, K.y := mT, K.w := mR - mL, K.h := mB - mT
            } else if (trybStr == "Anchor") {
                if (IsObject(Anchor) && HasProp(Anchor, "Gui")) {
                    sc := Utils.ClientToScreen(Anchor, Anchor.Gui.Hwnd)
                    K.x := sc.x, K.y := sc.y, K.w := sc.w, K.h := sc.h
                } else if (hCel) {
                    try WinGetPos(&cX, &cY, &cW, &cH, "ahk_id " hCel)
                    catch
                        cX := 0, cY := 0, cW := 0, cH := 0
                    K.x := cX, K.y := cY, K.w := cW, K.h := cH
                }
            }

            if (trybStr == "Mouse") {
                pt := Buffer(8), DllCall("GetCursorPos", "Ptr", pt)
                K.x := NumGet(pt, 0, "Int"), K.y := NumGet(pt, 4, "Int")
            }
            return { K: K, M: M }
        }

        if (tresc == "") {
            if IsObject(GuiTip)
                GuiTip.Destroy()
            GuiTip := 0, OstatniaTresc := "", OstatniCel := 0
            if (OstatniSilnikTooltipa) {
                OstatniSilnikTooltipa.Stan.AktywnyTooltip := 0
                OstatniSilnikTooltipa := 0
            }
            return
        }

        ; [BYPASS] Ignoruj DelayON dla żyjącego dymka pod tą samą kontrolką
        if (DelayON > 0 && tresc == OstatniaTresc && hCel == OstatniCel && IsObject(GuiTip)) {
            DelayON := 0
            opcje.DelayON := 0
        }

        if (DelayON > 0) {
            SilnikGUI.CustomTooltip("") ; Zabij obecny i zresetuj timery

            opcje.DelayON := 0 ; Zapobiegnij petli
            TimerOpoznienia := () => SilnikGUI.CustomTooltip(tresc, opcje)
            SetTimer(TimerOpoznienia, -DelayON)

            if (trybStr == "Anchor" && hCel && !HasProp(trybPozycji, "SkipMonitor"))
                TempMonitor := SilnikGUI.MonitorujWyjscie(() => SilnikGUI.CustomTooltip(""), [hCel], "Hover", 0, 0)

            return
        }

        ; Integracja motywu
        (kolorTla == "") && kolorTla := SilnikGUI.Motyw.Tlo
        (kolorTekstu == "") && kolorTekstu := SilnikGUI.Motyw.Tekst
        (kolorRamki == "") && kolorRamki := SilnikGUI.Motyw.Ramka

        Rysuj() {
            CzyPrzebudowacStyl := !IsObject(GuiTip) || (trybStr != OstatniTryb) || (igX != OstatnieIgX) || (igY != OstatnieIgY) || (kolorTla != OstatniKolorTla) || (kolorTekstu != OstatniKolorTekstu) || (kolorRamki != OstatniKolorRamki) || (MargPion != OstatniMargPion) || (MargPoz != OstatniMargPoz) || (rozmiarCzcionki != OstatniRozmiar) || (czyPogrubione != OstatniePogrubienie) || (Transparent != OstatniTransparent) || (TransClick !== OstatniTransClick)

            NoweSegmenty := []
            pos := 1, dlugosc := StrLen(tresc)
            while (pos <= dlugosc) {
                if RegExMatch(tresc, "\n\.(?:\[(\d{1,3})\])?\.\n", &match, pos) {
                    txtSegment := SubStr(tresc, pos, match.Pos - pos)
                    sepH := (match[1] == "") ? 1 : Integer(match[1])
                    NoweSegmenty.Push({ txt: txtSegment, sepH: sepH })
                    pos := match.Pos + match.Len
                } else {
                    NoweSegmenty.Push({ txt: SubStr(tresc, pos), sepH: 0 })
                    break
                }
            }

            MoznaWMiejscu := !CzyPrzebudowacStyl && HasProp(GuiTip, "Segmenty") && (NoweSegmenty.Length == GuiTip.Segmenty.Length)

            sMargPion := Round(MargPion * Skala)
            sMargPoz := Round(MargPoz * Skala)
            sGruboscRamki := Round(1 * Skala)

            maxW := 0
            FinalSize := Round((FontSize != 10 ? FontSize : rozmiarCzcionki) * FontMulti)
            fOpt := "s" . FinalSize . (czyPogrubione ? " bold" : " norm")
            for seg in NoweSegmenty {
                wym := SilnikGUI.ZmierzTekst(seg.txt, SilnikGUI.Statics.GlobFont.Name, fOpt)
                seg.w := wym.w, seg.h := wym.h
                maxW := Max(maxW, wym.w) + sMargPoz * 2
            }

            if (MoznaWMiejscu) {
                aktualneY := sGruboscRamki
                for i, item in GuiTip.Segmenty {
                    seg := NoweSegmenty[i]
                    if (item.main.Value != seg.txt)
                        item.main.Value := seg.txt

                    item.top.Move(sGruboscRamki, aktualneY, maxW, sMargPion)
                    aktualneY += sMargPion
                    item.main.Move(sGruboscRamki, aktualneY, maxW, seg.h)
                    aktualneY += seg.h
                    item.bot.Move(sGruboscRamki, aktualneY, maxW, sMargPion)
                    aktualneY += sMargPion
                    if (seg.sepH > 0)
                        aktualneY += Round(seg.sepH * Skala)
                }
                GuiTip.Move(, , maxW + 2 * sGruboscRamki, aktualneY + sGruboscRamki)
            } else {
                czyPrzenika := (TransClick !== "") ? TransClick : (trybStr == "Mouse")
                needsAlpha := (czyPrzenika || Transparent < 1.0)
                NoweGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000 " . (needsAlpha ? ((czyPrzenika ? "+E0x20 " : "")) : "+E0x02000000 ") . "-DPIScale" . (hOwner ? " +Owner" . hOwner : ""))
                if (needsAlpha) {
                    alphaVal := Round(255 * Transparent)
                    (czyPrzenika && alphaVal == 255) && alphaVal := 254
                    WinSetTransparent(alphaVal, NoweGui.Hwnd)
                }
                NoweGui.BackColor := kolorRamki
                NoweGui.MarginX := sGruboscRamki, NoweGui.MarginY := sGruboscRamki
                NoweGui.SetFont("s" . FinalSize . " " . FontOpt . " " . kolorTekstu . (czyPogrubione ? " bold" : ""), SilnikGUI.Statics.GlobFont.Name)

                NoweGui.Segmenty := []
                aktualneY := sGruboscRamki

                for seg in NoweSegmenty {
                    top := NoweGui.Add("Text", "x" . sGruboscRamki . " y" . aktualneY . " w" . maxW . " h" . sMargPion . " Background" . kolorTla, "")
                    aktualneY += sMargPion
                    main := NoweGui.Add("Text", "Center x" . sGruboscRamki . " y" . aktualneY . " w" . maxW . " h" . seg.h . " Background" . kolorTla, seg.txt)
                    aktualneY += seg.h
                    bot := NoweGui.Add("Text", "x" . sGruboscRamki . " y" . aktualneY . " w" . maxW . " h" . sMargPion . " Background" . kolorTla, "")
                    aktualneY += sMargPion
                    if (seg.sepH > 0)
                        aktualneY += Round(seg.sepH * Skala)

                    NoweGui.Segmenty.Push({ top: top, main: main, bot: bot })
                }

                NoweGui.Show("Hide w" . (maxW + 2 * sGruboscRamki) . " h" . (aktualneY + sGruboscRamki))

                StareGui := GuiTip
                GuiTip := NoweGui
                Utils.SetTag(GuiTip.Hwnd, "IsSilnikTooltip")
            }
            OstatniaTresc := tresc, OstatniKolorTla := kolorTla, OstatniKolorTekstu := kolorTekstu, OstatniKolorRamki := kolorRamki, OstatniMargPion := MargPion, OstatniMargPoz := MargPoz, OstatniRozmiar := rozmiarCzcionki, OstatniePogrubienie := czyPogrubione, OstatniCel := hCel, OstatniTryb := trybStr, OstatnieIgX := igX, OstatnieIgY := igY, OstatniTransparent := Transparent, OstatniTransClick := TransClick
        }
        Rysuj()

        ; [REFACTOR] Oblicz bazową pozycję TYLKO RAZ
        GuiTip.GetPos(, , &tipW, &tipH)

        isSkipMon := false
        Silnik := 0
        OffY := Round(24 * Skala), OffX := Round(15 * Skala)
        km := GetKObj()
        mAlignX := 0, mAlignY := 0

        switch trybStr {
            case "Screen", "Mouse":
                (trybStr == "Screen") && (OffY := 0, OffX := 0)
                ParsedAlign := SilnikGUI.ParsujAlign(Align)
                pos := SilnikGUI.DopasujDoKotwicy(trybStr, km.K, tipW, tipH, ParsedAlign, ParsedMove, OffY, OffX, km.M)
            case "Anchor":
                isSkipMon := HasProp(trybPozycji, "SkipMonitor")
                ParsedAlign := SilnikGUI.ParsujAlign(isSkipMon ? "+Up +Left" : Align)
                Silnik := (HasProp(trybPozycji, "Gui") && HasProp(trybPozycji.Gui, "Silnik")) ? trybPozycji.Gui.Silnik : 0
                OstatniSilnikTooltipa := Silnik
                for m in ParsedAlign {
                    if (m.pre == "m") {
                        (m.dir == "left" || m.dir == "right" || m.dir == "centerx") && mAlignX := 1
                        (m.dir == "up" || m.dir == "down" || m.dir == "centery") && mAlignY := 1
                    }
                }
                OffY := Round((isSkipMon ? 24 : 0) * Skala), OffX := Round((isSkipMon ? 15 : 0) * Skala)
                pos := SilnikGUI.DopasujDoKotwicy(trybStr, km.K, tipW, tipH, ParsedAlign, ParsedMove, OffY, OffX, km.M)
        }

        GuiTip.StartX := pos.x
        GuiTip.StartY := pos.y

        ; Zapisanie wektora startowego (Delta Tracking)
        if (igX || igY) {
            pt := Buffer(8), DllCall("GetCursorPos", "Ptr", pt)
            mX := NumGet(pt, 0, "Int"), mY := NumGet(pt, 4, "Int")
            GuiTip.DeltaX := pos.x - mX
            GuiTip.DeltaY := pos.y - mY
        }

        if (Silnik)
            Silnik.Stan.AktywnyTooltip := { Gui: GuiTip, WektorX: pos.x, WektorY: pos.y, IgnoreX: igX, IgnoreY: igY, StopX: ParsedMove.XStop, StopY: ParsedMove.YStop }

        GuiTip.Show("NA x" . pos.x . " y" . pos.y)

        UpdatePosition(TargetGui, isPendingKill := 0) {
            if !IsObject(TargetGui)
                return
            TargetGui.IsPendingKill := isPendingKill
            MouseGetPos(, , &win)
            freezeMTrack := (isPendingKill || (trybStr != "Mouse" && win == TargetGui.Hwnd))

            try {
                TargetGui.GetPos(&currX, &currY, &tw, &th)
                nKm := GetKObj()
                pos := SilnikGUI.DopasujDoKotwicy(trybStr, nKm.K, tw, th, ParsedAlign, ParsedMove, OffY, OffX, nKm.M)

                if (trybStr == "Anchor") {
                    (ParsedMove.XStop) && pos.x := TargetGui.StartX
                    (ParsedMove.YStop) && pos.y := TargetGui.StartY
                    ; Pasywna oś (Hybryda zdarzeniowa)
                    (ParsedMove.XATrack && mAlignX) && pos.x := currX
                    (ParsedMove.YATrack && mAlignY) && pos.y := currY
                }

                if (igX || igY) {
                    if (freezeMTrack) {
                        (igX) && pos.x := currX
                        (igY) && pos.y := currY
                    } else {
                        pt := Buffer(8), DllCall("GetCursorPos", "Ptr", pt)
                        mX := NumGet(pt, 0, "Int"), mY := NumGet(pt, 4, "Int")
                        (igX) && pos.x := mX + TargetGui.DeltaX
                        (igY) && pos.y := mY + TargetGui.DeltaY

                        (igX && !ParsedMove.NoClampX) && pos.x := Min(Max(pos.x, nKm.M.L), nKm.M.R - tw)
                        if (igY && trybStr != "Screen") {
                            (pos.y + th > nKm.M.B || pos.y < nKm.M.T) && pos.y := mY - TargetGui.DeltaY - th ; Delta Flip
                            pos.y := Min(Max(pos.y, nKm.M.T), nKm.M.B - th) ; Bezpiecznik
                        }
                    }
                }

                if (Silnik) {
                    t := Silnik.Stan.AktywnyTooltip
                    if (t) {
                        t.WektorX := pos.x
                        t.WektorY := pos.y
                        DllCall("SetWindowPos", "Ptr", TargetGui.Hwnd, "Ptr", 0, "Int", t.WektorX, "Int", t.WektorY, "Int", 0, "Int", 0, "UInt", 0x15)
                    }
                } else {
                    TargetGui.Move(pos.x, pos.y)
                }
            }
        }

        switch trybStr {
            case "Screen":
                ; Tryb statyczny - z założenia omija tworzenie timera
            case "Mouse":
                if (igX || igY) {
                    cbSledzenia := () => UpdatePosition(GuiTip)
                    SetTimer(cbSledzenia, SilnikGUI.TickRate)
                    TimerSledzenia := () => SetTimer(cbSledzenia, 0)
                }
            case "Anchor":
                isStatic := ((ParsedMove.XStop || (ParsedMove.XATrack && mAlignX)) && (ParsedMove.YStop || (ParsedMove.YATrack && mAlignY))) ; Zero-Math Mode
                if (isSkipMon) {
                    if (!isStatic) {
                        cbSledzenia := () => UpdatePosition(GuiTip)
                        SetTimer(cbSledzenia, SilnikGUI.TickRate)
                        TimerSledzenia := () => SetTimer(cbSledzenia, 0)
                    }
                } else {
                    TimerSledzenia := SilnikGUI.MonitorujWyjscie(() => SilnikGUI.CustomTooltip(""), [hCel, GuiTip.Hwnd], "Hover", isStatic ? 0 : UpdatePosition.Bind(GuiTip), DelayOFF)
                }
        }

        if IsObject(StareGui)
            StareGui.Destroy()

        if (czas > 0) {
            Zamknij() => SilnikGUI.CustomTooltip("")
            TimerZamykania := Zamknij
            SetTimer(Zamknij, -czas)
        }
    }

    /**
     * Wyświetla stylizowane okno błędu/ostrzeżenia (zastępuje MsgBox).
     * @param {String} Naglowek - Nagłówek wewnątrz okna (kolor ostrzegawczy).
     * @param {String} Tresc - Główny komunikat błędu.
     * @param {String} [Podtytul=""] - Dodatkowy opis (szary tekst).
     * @param {Integer} [ParentHwnd=0] - HWND okna rodzica (dla modalności/Owner).
     */
    static OknoBledu(Naglowek, Tresc, Podtytul := "", ParentHwnd := 0) {
        FontMulti := SilnikGUI.Statics.TotalScale
        pad := 10
        Opcje := "+AlwaysOnTop" . (ParentHwnd ? " +Owner" . ParentHwnd : "")
        Ostrzezenie := SilnikGUI(Naglowek, Opcje, { pokazPasek: 0, createChild: true, zamknijNaEsc: 0, CSBarV: 0, CSBarH: 0, ResizeMarg: 0, PadD: pad, PadR: pad }) ; 0=Off (Ręczna obsługa ESC)
        w := 320

        Ostrzezenie.GuiObj.SetFont("s" . Round(11 * FontMulti) . " bold", "Segoe UI")
        txtHead := Ostrzezenie.Add("Text", "Center w" w . " x10 y10 c" . SilnikGUI.Motyw.Ostrzezenie, Naglowek)
        txtHead.KolorBazowy := SilnikGUI.Motyw.Ostrzezenie

        Ostrzezenie.GuiObj.SetFont("s" . Round(10 * FontMulti) . " norm", "Segoe UI")
        Ostrzezenie.Add("Text", "Center w" w . " x10 y+5 c" . SilnikGUI.Motyw.Tekst, Tresc)
        if (Podtytul != "") {
            txtSub := Ostrzezenie.Add("Text", "Center w" w . " x10 y+5 c" . SilnikGUI.Motyw.Nieaktywny, Podtytul)
            txtSub.KolorBazowy := SilnikGUI.Motyw.Nieaktywny
        }

        ; Logika Auto-Kaskady i Sprzątania
        ZamknijISprzataj(*) {
            for i, okno in SilnikGUI.Statics.AktywneBledy
                if (okno == Ostrzezenie) {
                    SilnikGUI.Statics.AktywneBledy.RemoveAt(i)
                    break
                }
            Ostrzezenie.Zakoncz()

            ; Utrzymaj fokus na stosie błędów (jeśli są inne)
            if (SilnikGUI.Statics.AktywneBledy.Length > 0)
                try WinActivate(SilnikGUI.Statics.AktywneBledy[-1].GuiObj.Hwnd)
        }
        w2 := ((320 - 50) + pad * 2) / 2
        Ostrzezenie.DodajPrzycisk("OK", ZamknijISprzataj, "x" . w2 . " y+10 w50 h25")
        Ostrzezenie.Add("Button", "x0 y0 w0 h0 Hidden Default", "OK").OnEvent("Click", ZamknijISprzataj)
        Ostrzezenie.Stan.ChildGui.OnEvent("Close", ZamknijISprzataj) ; Nadpisz domyślny Close
        Ostrzezenie.Stan.ChildGui.OnEvent("Escape", ZamknijISprzataj) ; [FIX] ESC też musi sprzątać
        Ostrzezenie.Stan.ClipGui.OnEvent("Escape", ZamknijISprzataj)
        Ostrzezenie.GuiObj.OnEvent("Escape", ZamknijISprzataj)
        Ostrzezenie.Pokaz()

        if (SilnikGUI.Statics.AktywneBledy.Length > 0) {
            Offset := SilnikGUI.Statics.AktywneBledy.Length * 25 ; Auto-Offset 25px
            Ostrzezenie.GuiObj.GetPos(&x, &y)
            Ostrzezenie.GuiObj.Move(x + Offset, y + Offset)
        }
        SilnikGUI.Statics.AktywneBledy.Push(Ostrzezenie)
        return Ostrzezenie
    }

    /**
     * Wyświetla szybki dymek błędu przy kontrolce (z dźwiękiem), zintegrowany z motywem SilnikGUI.
     * @param {GuiCtrl} ctrl - Kontrolka, przy której ma się pojawić dymek.
     * @param {String} tresc - Tekst błędu do wyświetlenia.
     * @param {Integer} [ikona=3] - Typ ikony: 1=Info, 2=Ostrzeżenie, 3=Błąd.
     * @param {Integer} [czas=4000] - Czas wyświetlania w ms (domyślnie 4000ms = 4s).
     */

    static PokazDymekBledu(ctrl, tresc, ikona := 3, czas := 4000) {
        SoundPlay "*-1"
        if !CaretGetPos(&cX, &cY)
            MouseGetPos(&cX, &cY)
        ToolTip " ", cX, cY + 20, 10
        if (hwndTT := WinExist("ahk_class tooltips_class32 ahk_pid " ProcessExist())) {
            WinSetStyle "+0x40", hwndTT
            SendMessage(0x421, ikona, StrPtr("Niedozwolony znak"), hwndTT)
        }
        ToolTip tresc, cX, cY + 20, 10
        SetTimer () => ToolTip(, , , 10), -czas
    }

    /**
     * @desc Propaguje wektor przesunięcia do aktywnych popupów i pod-paneli.
     */
    PrzesunPopupy(dx, dy) {
        if (dx == 0 && dy == 0)
            return
        if (this.Stan.PopupActive && this.Stan.HasProp("PopupGuiObj") && this.Stan.PopupGuiObj) {
            pGui := this.Stan.PopupGuiObj
            lDx := ((HasProp(pGui, "IgnoreX") && pGui.IgnoreX) || (HasProp(pGui, "StopX") && pGui.StopX)) ? 0 : dx
            lDy := ((HasProp(pGui, "IgnoreY") && pGui.IgnoreY) || (HasProp(pGui, "StopY") && pGui.StopY)) ? 0 : dy
            if (lDx != 0 || lDy != 0) {
                pGui.WektorX += lDx, pGui.WektorY += lDy
                DllCall("SetWindowPos", "Ptr", pGui.Hwnd, "Ptr", 0, "Int", pGui.WektorX, "Int", pGui.WektorY, "Int", 0, "Int", 0, "UInt", 0x15)
            }
        }
        for dziecko in this.Stan.Dzieci
            dziecko.PrzesunPopupy(dx, dy)
    }

    /**
     * @desc Propaguje wektor przesunięcia do aktywnych dymków podpowiedzi.
     */
    PrzesunTooltipy(dx, dy) {
        if (dx == 0 && dy == 0)
            return
        if (this.Stan.HasProp("AktywnyTooltip") && this.Stan.AktywnyTooltip && WinExist("ahk_id " this.Stan.AktywnyTooltip.Gui.Hwnd)) {
            t := this.Stan.AktywnyTooltip
            lDx := ((HasProp(t, "IgnoreX") && t.IgnoreX) || (HasProp(t, "StopX") && t.StopX)) ? 0 : dx
            lDy := ((HasProp(t, "IgnoreY") && t.IgnoreY) || (HasProp(t, "StopY") && t.StopY)) ? 0 : dy
            if (lDx != 0 || lDy != 0) {
                t.WektorX += lDx, t.WektorY += lDy
                DllCall("SetWindowPos", "Ptr", t.Gui.Hwnd, "Ptr", 0, "Int", t.WektorX, "Int", t.WektorY, "Int", 0, "Int", 0, "UInt", 0x15)
            }
        }
        for dziecko in this.Stan.Dzieci
            dziecko.PrzesunTooltipy(dx, dy)
    }
}
/**
 * 4. WARSTWA FABRYKI
 * Metody tworzące kontrolki (API dla użytkownika).
 */
class CtlFactory extends ExWinAndPopups {
    /**
     * Dodaje natywną kontrolkę AHK do okna (ChildGui) i rejestruje ją w silniku.
     * Umożliwia bezpieczne dodawanie własnych elementów do layoutu.
     * @param {String} Type - Typ kontrolki (np. "Text", "Edit", "Button").
     * @param {String} [Options=""] - Opcje pozycyjne i stylowe.
     * @param {String} [Text=""] - Tekst kontrolki.
     * @param {Boolean} [ApplyScale=true] - Applies DPI scaling to options.
     * @param {Integer} [FontSize=10] - Bazowy rozmiar czcionki przed przemnożeniem.
     * @param {String} [FontOpt=""] - Opcje stylu czcionki (np. "bold cWhite").
     * @tag WinAPI: "IsSilnikControl"
     * @returns {GuiCtrl} - Utworzona kontrolka.
     */
    Add(Type, Options := "", Text := "", ApplyScale := true, FontSize := SilnikGUI.Statics.GlobFont.Size, FontOpt := "") {
        if (ApplyScale)
            Options := Utils.ScaleOptions(Options)

        FinalSize := Round(FontSize * SilnikGUI.Statics.TotalScale)
        this.Stan.ChildGui.SetFont("s" . FinalSize . " " . FontOpt, SilnikGUI.Statics.GlobFont.Name)

        ctrl := this.Stan.ChildGui.Add(Type, Options, Text)

        this.Stan.ChildGui.SetFont("s" . Round(10 * SilnikGUI.Statics.TotalScale) . " " . SilnikGUI.Motyw.Tekst, SilnikGUI.Statics.GlobFont.Name)

        this.Stan.Kontrolki.Push(ctrl)
        Utils.SetTag(ctrl.Hwnd, "IsSilnikControl")
        return SilnikGUI.GrupaKontrolek([ctrl], [ctrl])
    }

    /**
     * Dodaje standardowy wiersz konfiguracyjny: Etykieta + Pole Edycji w Ramce.
     * @param {String} etykieta - Tekst opisujący pole.
     * @param {Number} wartoscDomyslna - Wartość startowa. mozna użyć: Format("{:.2f}",Value)
     * @param {Object} [opcje] - Opcjonalny obiekt konfiguracyjny z parametrami:
     * - [trybWalidacji: 0] {Integer} 0=Int, 1=Float, 2=Brak, 3=Wieloliniowy.
     * - [minVal: ""] {Number} Minimalna wartość.
     * - [maxVal: ""] {Number} Maksymalna wartość.
     * - [skok: ""] {Number} Skok wartości dla scrolla.
     * - [pozycja: "xm"] {String}.
     * - [pokazBlad: true] {Boolean} Pokazuj dymek błędu.
     * - [czasSekundy: 4.0] {Number} Czas wyświetlania błędu.
     * - [SzerText: 0] {Number} Wymuszona szerokość etykiety.
     * - [SzerPola: 50] {Number} Szerokość pola edycji (0=Auto-Resize).
     * - [AutoCenter: false] {Boolean} Centrowanie wiersza.
     * - [SzRamki: 2] {Number} Grubość ramki.
     * - [obslugaEnter: 0] {Func} Callback dla Enter.
     * - [WysInput: 0] {Number} Wysokość pola edycji (w wierszach).
     * - [ResizeEdit: false] {Boolean} Dynamiczne dopasowanie szerokości pola do tekstu.
     * - [FontName: "SilnikGUI.Statics.GlobFont.Name"] {String} Nazwa czcionki.
     * - [FontSize: SilnikGUI.Statics.GlobFont.Size] {Number} Bazowy rozmiar czcionki przed przemnożeniem.
     * - [FontOpt: ""] {String} Opcje stylu czcionki (np. "bold").
     * - [EditOpt: "Center"] {String} Opcje dla Edit.
     * - [BackCol: "SilnikGUI.Motyw.Wklesly"] {String} Kolor tła (nazwa lub hex).
     * - [TextCol: "SilnikGUI.Motyw.Tekst"] {String} Kolor tekstu (nazwa lub hex).
     * - [Backlight: 1] {Number} podświetlenie tła Edita (0-1).
     * - [InfoRight: 0] {Integer} Etykieta z prawej strony (1) lub z lewej (0).
     * - [ApplyScale: true] {Boolean} Applies DPI scaling to numeric and positional options.
     * @tag WinAPI: "IsSilnikInput" (dla wszystkich elementów wiersza).
     * @returns {Gui.Edit} - Zwraca obiekt kontrolki Edit, aby można było pobrać z niego wartość.
     */
    DodajWierszKonfiguracji(etykieta, wartoscDomyslna, opcje?) {
        opcje := Utils.MergeOptions(opcje?, { trybWalidacji: 0, minVal: "", maxVal: "", skok: "", pozycja: "xm", pokazBlad: true, czasSekundy: 4.0, SzerText: 0, SzerPola: 50, AutoCenter: false, SzRamki: 2, obslugaEnter: 0, WysInput: 0, WysPola: 0, ResizeEditW: false, ResizeEditH: false, FontName: SilnikGUI.Statics.GlobFont.Name, FontSize: SilnikGUI.Statics.GlobFont.Size, FontOpt: "", EditOpt: "Center", BackCol: SilnikGUI.Motyw.Wklesly, TextCol: SilnikGUI.Motyw.Tekst, Backlight: 1, InfoRight: 0, ApplyScale: true })
        trybWalidacji := opcje.trybWalidacji, minVal := opcje.minVal, maxVal := opcje.maxVal, skok := opcje.skok, pozycja := opcje.ApplyScale ? Utils.ScaleOptions(opcje.pozycja) : opcje.pozycja, pokazBlad := opcje.pokazBlad, czasSekundy := opcje.czasSekundy, SzerText := opcje.SzerText, SzerPola := opcje.SzerPola, AutoCenter := opcje.AutoCenter, SzRamki := opcje.SzRamki, obslugaEnter := opcje.obslugaEnter, WysInput := opcje.WysInput, WysPola := opcje.WysPola, ResizeEditW := opcje.ResizeEditW, ResizeEditH := opcje.ResizeEditH, FontName := opcje.FontName, FontSize := opcje.FontSize, FontOpt := opcje.FontOpt, EditOpt := opcje.ApplyScale ? Utils.ScaleOptions(opcje.EditOpt) : opcje.EditOpt, Backlight := opcje.Backlight, InfoRight := opcje.InfoRight
        BackCol := SilnikGUI.PobierzHex(opcje.BackCol), TextCol := "c" . SilnikGUI.PobierzHex(opcje.TextCol)
        SzerPola := SzerPola - (2 * SzRamki)
        WysPola := WysPola - (2 * SzRamki)

        FinalSize := Round(FontSize * SilnikGUI.Statics.TotalScale)
        wymWiersz := SilnikGUI.ZmierzTekst("Wg", FontName, "s" . FinalSize . " " . FontOpt)
        hWiersza := wymWiersz.h

        Skala := (A_ScreenDPI / 96) * SilnikGUI.Statics.TotalScale

        ; Flaga dynamicznego pola (dopasowanie do tekstu)
        CzyDynamicznePole := (ResizeEditW || ResizeEditH)
        SzerPola := opcje.ApplyScale ? Round(SzerPola * Skala) : SzerPola
        WysPola := opcje.ApplyScale ? Round(WysPola * Skala) : WysPola
        WysWiersza := hWiersza + (opcje.ApplyScale ? Round(4 * Skala) : 4)
        WysInput := WysPola > 0 ? WysPola : (trybWalidacji != 3 ? hWiersza : (WysInput > 0 ? (hWiersza * WysInput) : (hWiersza * (StrSplit(String(wartoscDomyslna), "`n", "`r").Length + 1))))
        Grubosc := opcje.ApplyScale ? Round(SzRamki * Skala) : SzRamki

        ; Stabilizacja pozycji Y przy użyciu elementu Dummy
        dummy := this.Stan.ChildGui.Add("Text", pozycja . " w0 h0 Hidden")
        dummy.IsDummy := true
        dummy.GetPos(&dX, &dY)

        ; 1. Etykieta (Pozycjonowanie absolutne względem dummy)
        if (etykieta != "") {
            wymEtyk := SilnikGUI.ZmierzTekst(etykieta, FontName, "s" . FinalSize)
            wRzeczywiste := wymEtyk.w + Round(FinalSize * 0.5) + 5 ; Dynamiczny margines bezpieczeństwa

            SzerFinalnaEtykiety := (SzerText > 0) ? Round(SzerText * Skala) : wRzeczywiste
            EtykX := InfoRight ? dX + SzerPola + (SzRamki > 0 ? 2 * Grubosc : 0) + 10 : dX

            OpcjeText := "x" . EtykX . " y" . dY . " w" . SzerFinalnaEtykiety . " h" . WysWiersza . " +0x200 +0x100"
            txtCtrl := this.Stan.ChildGui.Add("Text", OpcjeText, etykieta)
            txtCtrl.SetFont("s" . FinalSize . " " . FontOpt, FontName)
        } else {
            SzerFinalnaEtykiety := 0
        }

        ; 2. Ramka i Pole Edycji (Pozycjonowanie absolutne względem dummy)
        RamkaX := InfoRight ? dX : dX + SzerFinalnaEtykiety

        poleEdit := this.Stan.ChildGui.Add("Edit", "x" . (RamkaX + Grubosc) . " y" . (dY + Grubosc) . " w" . SzerPola . " h" . WysInput . " " . EditOpt . " -E0x200 -VScroll Background" . BackCol, wartoscDomyslna)
        poleEdit.SetFont("s" . FinalSize . " " . FontOpt . " " . TextCol, FontName)
        this.Stan.Kontrolki.Push(poleEdit)
        if SzRamki > 0
            ramkaObj := this.Ramka(poleEdit, 0, 0, "", Grubosc, , 0)
        ; [FIX] Inteligentna karetka: Pamięć pozycji, brak to wieloliniowe do początku (0), jednoliniowe do końca
        poleEdit.OnEvent("LoseFocus", (ctrl, *) => (SendMessage(0x00B0, wp := Buffer(4), 0, ctrl), ctrl.LastCaretPos := NumGet(wp, "UInt")))
        poleEdit.OnEvent("Focus", (ctrl, *) => SetTimer(() => (HasProp(ctrl, "LBtnDownTick") && A_TickCount - ctrl.LBtnDownTick < 50) ? "" : (pos := HasProp(ctrl, "LastCaretPos") ? ctrl.LastCaretPos : ((trybWalidacji == 3) ? 0 : StrLen(ctrl.Value)), PostMessage(0xB1, pos, pos, ctrl)), -10))

        ; Znacznik interakcji dla centralnego routera fokusu
        poleEdit.MouseDownAction := (ctrl, *) => ctrl.LBtnDownTick := A_TickCount

        ; Powiązanie kontrolek-dzieci z rodzicem (dla Hover/Focus)
        if (etykieta != "") {
            txtCtrl.ParentCtrl := poleEdit
            poleEdit.EtykietaCtrl := txtCtrl ; Przypisanie PO Ramka(), aby nie objęła etykiety
        }
        if SzRamki > 0 {
            ramkaObj.ParentCtrl := poleEdit
            poleEdit.Ramka := ramkaObj
        }
        poleEdit.SzerEtykiety := SzerFinalnaEtykiety
        poleEdit.BazoweX := dX ; Bazowe X
        poleEdit.AutoCenter := AutoCenter ; Flaga centrowania
        poleEdit.GruboscRamki := Grubosc
        poleEdit.FontName := FontName
        poleEdit.FontSize := FontSize
        poleEdit.WysWiersza := hWiersza
        poleEdit.ResizeEditW := ResizeEditW
        poleEdit.ResizeEditH := ResizeEditH
        poleEdit.CzyDynamiczne := CzyDynamicznePole ; Znacznik dla Pokaz (ochrona statycznych)
        poleEdit.SzerPola := SzerPola ; Przechowuje szerokość pola (niezależnie od dynamicznego dopasowania)
        poleEdit.WysInput := WysInput ; Zapisz wynikową wyskość jako kaganiec
        if Backlight == 1
            poleEdit.KolorBazowyTla := BackCol
        poleEdit.KolorBazowy := TextCol
        poleEdit.InfoRight := InfoRight

        ; 4. Walidacja i zdarzenia
        if (trybWalidacji == 1) ; Float
            poleEdit.OnEvent("Change", (ctrl, info) => SilnikGUI.WalidujFloat(ctrl, info, pokazBlad, czasSekundy))
        else if (trybWalidacji == 0) ; Integer
            poleEdit.OnEvent("Change", (ctrl, info) => SilnikGUI.WalidujInt(ctrl, info, pokazBlad, czasSekundy))
        ; Tryb 2: Brak walidacji

        ; 5. Polimorfizm: Definicja zachowania scrolla
        if (trybWalidacji < 2) {
            ScrollAction(ctrl, kierunek) {
                val := Number(StrReplace(ctrl.Value, ",", "."))

                ; Detekcja trybu float (z konfiguracji, zawartości lub skoku)
                isFloatMode := (trybWalidacji == 1) || InStr(ctrl.Value, ".") || InStr(ctrl.Value, ",") || (skok != "" && InStr(skok, "."))

                step := (skok != "") ? skok : (isFloatMode ? 0.1 : 1)

                res := SilnikGUI.ObliczLimit(val, kierunek * step, minVal, maxVal)
                (res.Flash) && SilnikGUI.EfektFlash(ctrl)

                ctrl.Value := isFloatMode ? Format("{:.2f}", res.V) : Integer(res.V)
                try ctrl.GetMethod("OnEvent")("Change", ctrl)
            }
            poleEdit.VScrollAction := ScrollAction
            poleEdit.HArrowNeed := true
        } else if (trybWalidacji == 2) {
            poleEdit.HArrowNeed := true
        } else if (trybWalidacji == 3) {
            poleEdit.ArrowNeed := true
            poleEdit.NativeEnter := true
        }

        ; 6. Walidacja końcowa (LoseFocus) - Gwarantuje poprawność przy wpisywaniu ręcznym
        if (minVal != "" || maxVal != "") {
            poleEdit.OnEvent("LoseFocus", (ctrl, *) => (
                val := Number(StrReplace(ctrl.Value, ",", ".") || 0),
                (minVal != "") && val := Max(val, minVal),
                (maxVal != "") && val := Min(val, maxVal),
                ctrl.Value := (trybWalidacji == 1) ? Format("{:.2f}", val) : Integer(val)
            ))
        }

        ; 7. Obsługa Enter (Nawigacja)
        if (obslugaEnter && trybWalidacji != 3)
            poleEdit.OnEnter := obslugaEnter

        if (CzyDynamicznePole) {
            poleEdit.Value := wartoscDomyslna
            this.DostosujRozmiar(SzerFinalnaEtykiety, poleEdit, SzerPola, WysInput)
            PostMessage(0xB1, StrLen(poleEdit.Value), StrLen(poleEdit.Value), poleEdit)
            poleEdit.OnEvent("Change", (ctrl, *) => (
                this.DostosujRozmiar(SzerFinalnaEtykiety, ctrl, SzerPola, WysInput)
            ))
        }

        ; Bounding Box - pozycjonowanie dla kolejnych kontrolek (xp, xm, y+)
        SzerCalkowita := SzerFinalnaEtykiety + SzerPola + (2 * Grubosc) + ((InfoRight && SzerFinalnaEtykiety > 0) ? 10 : 0)
        WysCalkowita := Max(WysWiersza, WysInput + (2 * Grubosc))
        BoundingBox := this.Stan.ChildGui.Add("Text", "x" . dX . " y" . dY . " w" . SzerCalkowita . " h" . WysCalkowita . " Hidden")
        BoundingBox.IsDummy := true
        poleEdit.BoundingBox := BoundingBox

        ; [TAGOWANIE WinAPI] Oznacz elementy wiersza dla #HotIf
        Utils.SetTag(poleEdit.Hwnd, "IsSilnikInput")
        if (etykieta != "")
            Utils.SetTag(txtCtrl.Hwnd, "IsSilnikInput")
        if (SzRamki > 0)
            for c in ramkaObj.Ctrls
                Utils.SetTag(c.Hwnd, "IsSilnikInput")

        ElementyGrupy := [poleEdit, BoundingBox]
        (etykieta != "") && ElementyGrupy.Push(txtCtrl)
        (SzRamki > 0) && ElementyGrupy.Push(ramkaObj)

        return SilnikGUI.GrupaKontrolek([poleEdit], ElementyGrupy)
    }

    /**
     * Dodaje Checkbox w stylu aplikacji.
     * @desc Customowa implementacja: Emuluje Checkbox na bazie kontrolek Text, bez użycia natywnego komponentu.
     * @param {String} tekst - Etykieta kontrolki.
     * @param {Object} [opcje] - Opcje: {[czyZaznaczony: false], [pozycja: "xm"], [InfoRight: 1]pozycja: "xm", InfoRight: 1}.
     * - [ApplyScale: true] {Boolean} Applies DPI scaling to numeric and positional options.
     * - [FontSize: SilnikGUI.Statics.GlobFont.Size] {Integer} Bazowy rozmiar czcionki przed przemnożeniem.
     * - [FontOpt: ""] {String} Opcje stylu czcionki (np. "bold").
     * @tag WinAPI: "IsSilnikInput" (dla znaczników, tekstu i ramki).
     * @returns {Gui.Checkbox} - Zwraca obiekt kontrolki Checkbox z dodaną właściwością `LabelX` (współrzędna X etykiety).
     */
    DodajCheckbox(tekst, opcje?) {
        opcje := Utils.MergeOptions(opcje?, { czyZaznaczony: false, pozycja: "", InfoRight: 1, ApplyScale: true, FontSize: SilnikGUI.Statics.GlobFont.Size, FontOpt: "" })
        czyZaznaczony := opcje.czyZaznaczony, pozycja := opcje.ApplyScale ? Utils.ScaleOptions(opcje.pozycja) : opcje.pozycja, InfoRight := opcje.InfoRight
        FinalSize := opcje.FontSize ; * SilnikGUI.Statics.TotalScale
        Skala := (A_ScreenDPI / 96) * SilnikGUI.Statics.TotalScale
        WymiarBox := opcje.ApplyScale ? Round(1.4 * FinalSize * Skala) : Round(1.4 * FinalSize)
        Grubosc := opcje.ApplyScale ? Round(2 * Skala) : 2

        dummy := this.Stan.ChildGui.Add("Text", pozycja . " w0 h0 Hidden"), dummy.GetPos(&dX, &dY)
        dummy.IsDummy := true

        myLabelDim := SilnikGUI.ZmierzTekst(tekst, SilnikGUI.Statics.GlobFont.Name, "s" . Round(opcje.FontSize * SilnikGUI.Statics.TotalScale) . " " . opcje.FontOpt)
        myLabelWidth := myLabelDim.w

        if (InfoRight) {
            CheckMark := this.Stan.ChildGui.Add("Text", "x" . (dX + Grubosc) . " y" . (dY + Grubosc) . " w" . WymiarBox . " h" . WymiarBox . " Center +0x200 +Tabstop +0x100 Background" . SilnikGUI.Motyw.Wklesly . " c" . SilnikGUI.Motyw.Tekst, czyZaznaczony ? "✓" : "")
            CheckMark.SetFont("s" . Round(opcje.FontSize * 1.2 * SilnikGUI.Statics.TotalScale) . " bold " . opcje.FontOpt, SilnikGUI.Statics.GlobFont.Name)
            this.Stan.Kontrolki.Push(CheckMark)
            ramkaObj := this.Ramka(CheckMark, 0, 0, "", Grubosc, , 0)
            txt := this.Stan.ChildGui.Add("Text", "x+10 yp w" . myLabelWidth . " h" . (WymiarBox + 2 * Grubosc) . " +0x200 +0x100", tekst)
            txt.SetFont("s" . Round(opcje.FontSize * SilnikGUI.Statics.TotalScale) . " " . opcje.FontOpt, SilnikGUI.Statics.GlobFont.Name)
        } else {
            txt := this.Stan.ChildGui.Add("Text", "x" . dX . " y" . dY . " w" . myLabelWidth . " h" . (WymiarBox + 2 * Grubosc) . " +0x200 +0x100", tekst)
            txt.SetFont("s" . Round(opcje.FontSize * SilnikGUI.Statics.TotalScale) . " " . opcje.FontOpt, SilnikGUI.Statics.GlobFont.Name)
            CheckMark := this.Stan.ChildGui.Add("Text", "x" . (dX + myLabelWidth + 10 + Grubosc) . " y" . (dY + Grubosc) . " w" . WymiarBox . " h" . WymiarBox . " Center +0x200 +Tabstop +0x100 Background" . SilnikGUI.Motyw.Wklesly . " c" . SilnikGUI.Motyw.Tekst, czyZaznaczony ? "✓" : "")
            CheckMark.SetFont("s" . Round(opcje.FontSize * 1.2 * SilnikGUI.Statics.TotalScale) . " bold " . opcje.FontOpt, SilnikGUI.Statics.GlobFont.Name)
            this.Stan.Kontrolki.Push(CheckMark)
            ramkaObj := this.Ramka(CheckMark, 0, 0, "", Grubosc, , 0)
        }

        txt.GetPos(&labelX, , &tW, &tH)

        ; Bounding Box - pozycjonowanie dla kolejnych kontrolek (xp, xm, y+)
        SzerCalkowita := tW + WymiarBox + (2 * Grubosc) + 10
        WysCalkowita := Max(tH, WymiarBox + (2 * Grubosc))
        BoundingBox := this.Stan.ChildGui.Add("Text", "x" . dX . " y" . dY . " w" . SzerCalkowita . " h" . WysCalkowita . " Hidden")
        BoundingBox.IsDummy := true
        CheckMark.BoundingBox := BoundingBox

        ; 4. Konfiguracja Obiektu
        CheckMark.LabelX := labelX
        CheckMark.InternalValue := czyZaznaczony
        CheckMark.Rola := "Checkbox"
        CheckMark.GruboscRamki := Grubosc
        CheckMark.UserCallbacks := []
        CheckMark.InfoRight := InfoRight

        ; Powiązania dla NadajStyl
        CheckMark.Ramka := ramkaObj
        CheckMark.EtykietaCtrl := txt ; Przypisanie PO Ramka()

        ; Powiązania ParentCtrl (dla Hover/Focus w MonitorujStan)
        txt.ParentCtrl := CheckMark
        ramkaObj.ParentCtrl := CheckMark

        ; Nadpisanie właściwości Value (Logika 0/1 -> Tekst)
        CheckMark.DefineProp("Value", {
            Get: (*) => CheckMark.InternalValue,
            Set: (self, val) => (self.InternalValue := !!val, self.Text := self.InternalValue ? "✓" : "")
        })

        ; Wyzwalacz zmian (musi być zdefiniowany przed użyciem w OnEvent)
        WyzwalaczZmiany(c, *) {
            c.Value := !c.Value
            for cb in c.UserCallbacks
                cb.Call(c, 0)
        }

        ; [MOD] Bezpośrednia akcja na wciśnięcie (Instant)
        CheckMark.MouseDownAction := WyzwalaczZmiany

        ; Nadpisanie OnEvent (Przechwytywanie zewnętrznych subskrypcji)
        CheckMark.DefineProp("OnEvent", {
            Call: (self, event, callback, add := 1) => (
                event = "Click" && add ? self.UserCallbacks.Push(callback) : 0
            )
        })

        ; [MOD] Przekierowanie (ParentCtrl w ObslugaInterakcji załatwia sprawę, ale dla pewności przypisujemy dane)
        ; Dzięki logice w ObslugaInterakcji, kliknięcie w ramkę znajdzie ParentCtrl (CheckMark) i użyje jego MultiklikData
        ramkaObj.ParentCtrl := CheckMark
        txt.ParentCtrl := CheckMark


        ; Scroll zmienia stan
        ScrollAction(ctrl, kierunek) {
            nowyStan := (kierunek > 0)
            if (ctrl.Value != nowyStan) {
                WyzwalaczZmiany(ctrl)
            } else
                SilnikGUI.EfektFlash(ctrl) ; Kolizja z limitem
        }
        CheckMark.VScrollAction := ScrollAction

        ; Obsługa Enter
        CheckMark.OnEnter := (ctrl) => ctrl.MouseDownAction()

        ; [TAGOWANIE WinAPI]
        Utils.SetTag(CheckMark.Hwnd, "IsSilnikInput")
        Utils.SetTag(txt.Hwnd, "IsSilnikInput")
        for c in ramkaObj.Ctrls
            Utils.SetTag(c.Hwnd, "IsSilnikInput")

        return SilnikGUI.GrupaKontrolek([CheckMark], [CheckMark, ramkaObj, txt, BoundingBox])
    }

    /**
     * Dodaje Custom DropDownList (DDList) - Faza 1: Kotwica.
     * @param {Array} opcje - Tablica opcji (Strings).
     * @param {Func} [callback=0] - Funkcja wywoływana po zmianie (ctrl, index).
     * @param {Integer} [wybranyIndex=1] - Domyślnie wybrany indeks.
     * @param {Integer} [szerokosc=200] - Szerokość kontrolki.
     * @param {String} [pozycja="xm"] - Pozycja (np. "xm", "y+10").
     * @param {Intiger} [Padding=0] - Czy wyśrodkować tekst (w kotwicy i popupie) 0= centrowanie.
     * @param {Integer} [Ramkapopupu=1] - Grubość ramki okna popup (domyślnie 1px).
     * @param {Integer} [SeparatorW=1] - Grubość separatora pionowego (domyślnie 1px).
     * @param {Boolean} [ApplyScale=true] - Applies DPI scaling to numeric and positional options.
     * @param {Object} [fontOptions] - Opcje czcionki: {FontSize: SilnikGUI.Statics.GlobFont.Size, FontOpt: ""}.
     * @tag WinAPI: "IsSilnikInput" (dla tekstu, strzałki i ramki).
     */
    DodajDDList(opcje, callback := 0, wybranyIndex := 1, szerokosc := 200, pozycja := "xm", Padding := 0, Ramkapopupu := 1, SeparatorW := 1, ApplyScale := true, fontOptions?) {
        fontOptions := Utils.MergeOptions(fontOptions?, { FontSize: SilnikGUI.Statics.GlobFont.Size, FontOpt: "" })
        FinalSize := fontOptions.FontSize
        Skala := (A_ScreenDPI / 96) * SilnikGUI.Statics.TotalScale
        if (ApplyScale) {
            pozycja := Utils.ScaleOptions(pozycja)
            szerokosc := Round(szerokosc * Skala)
            Ramkapopupu := Round(Ramkapopupu * Skala)
        }
        WysWiersza := ApplyScale ? Round(2.2 * FinalSize * Skala) : Round(2.2 * FinalSize)
        Grubosc := ApplyScale ? Round(2 * Skala) : 2
        ArrowW := ApplyScale ? Round(2.0 * FinalSize * Skala) : Round(2.0 * FinalSize)
        SepW := ApplyScale ? Round(SeparatorW * Skala) : SeparatorW
        Prefix := Format("{:" . (Padding) . "}", "")
        ParsedAlign := SilnikGUI.ParsujAlign("+Down +Left")

        dummy := this.Stan.ChildGui.Add("Text", pozycja . " w0 h0 Hidden"), dummy.GetPos(&dX, &dY)
        dummy.IsDummy := true
        ; 2. Kontrolka Wartości (Text z Tabstop dla Focusu)
        SzerText := szerokosc - (2 * Grubosc) - ArrowW - SepW
        AlignOpt := Padding == 0 ? "Center" : ""
        ValueCtrl := this.Stan.ChildGui.Add("Text", "x" . (dX + Grubosc) . " y" . (dY + Grubosc) . " w" . SzerText . " h" . WysWiersza . " +0x200 +0x100 +Tabstop " . AlignOpt . " Background" . SilnikGUI.Motyw.Wklesly . " " . SilnikGUI.Motyw.Tekst, Prefix . opcje[wybranyIndex])

        ValueCtrl.SetFont("s" . Round(fontOptions.FontSize * SilnikGUI.Statics.TotalScale) . " " . fontOptions.FontOpt, SilnikGUI.Statics.GlobFont.Name)
        ArrowCtrl := this.Stan.ChildGui.Add("Text", "x+" . SepW . " yp w" . ArrowW . " h" . WysWiersza . " +0x200 +0x100 Center Background" . SilnikGUI.Motyw.Wklesly . " " . SilnikGUI.Motyw.Tekst, "▼")
        ArrowCtrl.SetFont("s" . Round(fontOptions.FontSize * 0.8 * SilnikGUI.Statics.TotalScale) . " " . fontOptions.FontOpt, SilnikGUI.Statics.GlobFont.Name)

        ; 4. Konfiguracja Obiektu
        ValueCtrl.Opcje := opcje
        ValueCtrl.SelectedIndex := wybranyIndex
        ValueCtrl.Callback := callback
        ValueCtrl.Rola := "DDList" ; Dla MonitorujStan
        ValueCtrl.GruboscRamki := Grubosc
        ValueCtrl.PopupGui := 0

        ; Powiązania (Hover/Focus)
        ArrowCtrl.ParentCtrl := ValueCtrl
        ValueCtrl.ArrowCtrl := ArrowCtrl ; Przypisanie PRZED Ramka(), aby objęła strzałkę
        this.Stan.Kontrolki.Push(ValueCtrl)
        ramkaObj := this.Ramka(ValueCtrl, 0, 0, "", Grubosc, , 0)
        ramkaObj.ParentCtrl := ValueCtrl
        ValueCtrl.Ramka := ramkaObj

        ; 5. Logika Scrolla (Zmiana wartości w miejscu LUB nawigacja w liście)
        _ScrollAction(ctrl, k) {
            if (ValueCtrl.PopupGui) {
                ; Tryb otwarty: Tylko wizualnie
                res := SilnikGUI.ObliczLimit(ctrl.SelectedIndex, -k, 1, ctrl.Opcje.Length)
                (res.Flash) && SilnikGUI.EfektFlash(ValueCtrl)
                ctrl.SelectedIndex := res.V
                SilnikGUI.AktualizujListe(ValueCtrl.PopupGui.ListCtrls, ValueCtrl.SelectedIndex)
            } else {
                ; Tryb zamknięty: Zmiana wartości
                res := SilnikGUI.ObliczLimit(ctrl.SelectedIndex, -k, 1, ctrl.Opcje.Length)
                (res.Flash) && SilnikGUI.EfektFlash(ctrl)
                ctrl.SelectedIndex := res.V
                ctrl.Value := Prefix . ctrl.Opcje[ctrl.SelectedIndex]
                if (ctrl.Callback)
                    ctrl.Callback.Call(ctrl, ctrl.SelectedIndex)
            }
        }
        ValueCtrl.DefineProp("VScrollAction", { Call: _ScrollAction })

        ; InputHook (Tylko Escape - resztę obsługuje InicjalizujSkroty)
        ih := InputHook("V")
        ih.KeyOpt("{Escape}", "NS")
        ih.OnKeyDown := (hook, vk, sc) => Zamknij()

        ; Inteligentny Enter (Otwórz / Zatwierdź)
        _OnEnter(ctrl) {
            if (ValueCtrl.PopupGui) {
                ValueCtrl.Value := Prefix . ValueCtrl.Opcje[ValueCtrl.SelectedIndex]
                if (ValueCtrl.Callback)
                    ValueCtrl.Callback.Call(ValueCtrl, ValueCtrl.SelectedIndex)
                Zamknij()
            } else {
                Otworz()
            }
        }
        ValueCtrl.DefineProp("OnEnter", { Call: _OnEnter })

        ; Logika Popup
        Zamknij(*) {
            if (this.GuiObj) {
                this.Stan.PopupActive := false
                try this.GuiObj.DeleteProp("PopupActive")
                try (this.Stan.UseChild) && this.Stan.ChildGui.DeleteProp("PopupActive")
            }
            ih.Stop()
            if (HasProp(ValueCtrl, "Watchdog") && ValueCtrl.Watchdog) {
                ValueCtrl.Watchdog()
                ValueCtrl.Watchdog := 0
            }
            if (ValueCtrl.PopupGui) {
                try ValueCtrl.PopupGui.Destroy()
                ValueCtrl.PopupGui := 0
            }
            this.Stan.PopupHwnd := 0
            this.Stan.PopupGuiObj := 0
        }

        Otworz(*) {
            if (ValueCtrl.PopupGui)
                return

            this.Stan.PopupActive := true
            this.GuiObj.PopupActive := true
            (this.Stan.UseChild) && this.Stan.ChildGui.PopupActive := true

            ; 1. Pozycja (Smart Positioning względem ramki)
            wysokoscListy := (ValueCtrl.Opcje.Length * WysWiersza)
            try WinGetPos(&rX, &rY, &rW, &rH, "ahk_id " ramkaObj.Hwnd)
            catch
                rX := 0, rY := 0, rW := 0, rH := 0
            MonitorGetWorkArea(MonitorGetPrimary(), &mL, &mT, &mR, &mB)
            pos := SilnikGUI.DopasujDoKotwicy("Anchor", { x: rX, y: rY, w: rW, h: rH }, szerokosc, wysokoscListy + (2 * Ramkapopupu), ParsedAlign, SilnikGUI.ParsujMove("NoClampX"), 0, 0, { L: mL, T: mT, R: mR, B: mB })

            ; 2. GUI Popup
            pGui := Gui("-Caption +ToolWindow +AlwaysOnTop +E0x08000000 +Owner" . this.GuiObj.Hwnd . " -DPIScale")
            hRoot := DllCall("GetAncestor", "Ptr", this.GuiObj.Hwnd, "UInt", 2, "Ptr")
            if IsNumber(pAlpha := WinGetTransparent(hRoot)) {
                WinSetTransparent(pAlpha, pGui.Hwnd)
            }
            pGui.BackColor := SilnikGUI.Motyw.Ramka
            pGui.MarginX := Ramkapopupu, pGui.MarginY := Ramkapopupu ; Ramka dynamiczna
            pGui.SetFont("s" . Round(fontOptions.FontSize * SilnikGUI.Statics.TotalScale) . " " . SilnikGUI.Motyw.Tekst, SilnikGUI.Statics.GlobFont.Name)
            pGui.ListCtrls := []
            pGui.Silnik := this ; [FIX] Przypisanie instancji silnika dla logiki MonitorujStan
            this.Stan.PopupHwnd := pGui.Hwnd
            pGui.WektorX := pos.x, pGui.WektorY := pos.y
            pGui.Zamknij := Zamknij ; [FIX] Interfejs zamykania
            this.Stan.PopupGuiObj := pGui


            ; 3. Elementy
            for i, opcja in ValueCtrl.Opcje {
                bg := (i == ValueCtrl.SelectedIndex) ? SilnikGUI.Motyw.Focus : SilnikGUI.Motyw.Przycisk
                ram := (i == ValueCtrl.SelectedIndex) ? SilnikGUI.Odcien(SilnikGUI.Motyw.Ramka, SilnikGUI.Motyw.ParamFocus) : SilnikGUI.Motyw.Ramka

                yPos := (i == 1) ? "y" . Ramkapopupu : "y+0"

                if (Padding == 0) {
                    ; [TRYB CENTER] Dzielimy wiersz na 3 części: Left (wyrównanie), Main (tekst), Right (reszta)
                    ; Zapewnia to idealne pokrycie pozycji X tekstu w popupie i kotwicy.
                    LeftW := (Grubosc) - Ramkapopupu
                    l := pGui.Add("Text", "x" . Ramkapopupu . " " . yPos . " w" . LeftW . " h" . WysWiersza . " +0x200 Background" . bg)
                    t := pGui.Add("Text", "x+0 yp w" . SzerText . " h" . WysWiersza . " +0x200 Center Background" . bg, opcja)
                    r1 := pGui.Add("Text", "x+0 yp w" . SepW . " h" . WysWiersza . " +0x200 Background" . ram)
                    r2 := pGui.Add("Text", "x+0 yp w" . (szerokosc - (Ramkapopupu + LeftW + SzerText) - Ramkapopupu - SepW) . " h" . WysWiersza . " +0x200 Background" . bg)

                    itemObj := { Main: t, Left: l, Right1: r1, Right2: r2 }
                    pGui.ListCtrls.Push(itemObj)

                    bindClick := ((idx, val, *) => (ValueCtrl.SelectedIndex := idx, ValueCtrl.Value := Prefix . val, (ValueCtrl.Callback) && ValueCtrl.Callback.Call(ValueCtrl, idx), Zamknij())).Bind(i, opcja)
                    bindHover := ((idx, *) => (ValueCtrl.SelectedIndex != idx && (ValueCtrl.SelectedIndex := idx, SilnikGUI.AktualizujListe(ValueCtrl.PopupGui.ListCtrls, ValueCtrl.SelectedIndex)))).Bind(i)

                    t.OnEvent("Click", bindClick), l.OnEvent("Click", bindClick), r1.OnEvent("Click", bindClick)
                    t.OnEvent("Click", bindClick), l.OnEvent("Click", bindClick), r2.OnEvent("Click", bindClick)
                    t.HoverAction := bindHover, l.HoverAction := bindHover, r1.HoverAction := bindHover
                    t.HoverAction := bindHover, l.HoverAction := bindHover, r2.HoverAction := bindHover
                } else {
                    t := pGui.Add("Text", "x" . Ramkapopupu . " " . yPos . " w" . (szerokosc - (2 * Ramkapopupu)) . " h" . WysWiersza . " +0x200 Background" . bg, Prefix . opcja)
                    pGui.ListCtrls.Push(t)
                    t.OnEvent("Click", ((idx, val, *) => (ValueCtrl.SelectedIndex := idx, ValueCtrl.Value := Prefix . val, (ValueCtrl.Callback) && ValueCtrl.Callback.Call(ValueCtrl, idx), Zamknij())).Bind(i, opcja))
                    t.HoverAction := ((idx, *) => (ValueCtrl.SelectedIndex != idx && (ValueCtrl.SelectedIndex := idx, SilnikGUI.AktualizujListe(ValueCtrl.PopupGui.ListCtrls, ValueCtrl.SelectedIndex)))).Bind(i)
                }
            }

            pGui.Show("x" . pos.x . " y" . pos.y . " w" . szerokosc . " NA")
            ValueCtrl.PopupGui := pGui
            ih.Start()

            ; 4. Watchdog (Zamykanie po kliknięciu poza) - Użycie uniwersalnego strażnika
            ValueCtrl.Watchdog := SilnikGUI.MonitorujWyjscie(Zamknij, [pGui.Hwnd, ValueCtrl.Hwnd, ArrowCtrl.Hwnd, ramkaObj.Top.Hwnd, ramkaObj.Bot.Hwnd, ramkaObj.Left.Hwnd, ramkaObj.Right.Hwnd], "Click")
        }

        Toggle := (c, *) => (ValueCtrl.PopupGui ? Zamknij() : (SilnikGUI.CzyMoznaInterakcja(ValueCtrl) && Otworz()))

        ; [MOD] Bezpośrednia akcja na wciśnięcie
        ValueCtrl.MouseDownAction := Toggle
        ; ArrowCtrl i Ramka obsłużą to przez ParentCtrl w ObslugaInterakcji

        ; [TAGOWANIE WinAPI]
        Utils.SetTag(ValueCtrl.Hwnd, "IsSilnikInput")
        Utils.SetTag(ArrowCtrl.Hwnd, "IsSilnikInput")
        for c in ramkaObj.Ctrls
            Utils.SetTag(c.Hwnd, "IsSilnikInput")

        return SilnikGUI.GrupaKontrolek([ValueCtrl, ArrowCtrl], [ValueCtrl, ArrowCtrl, ramkaObj])
    }

    /**
     * Dodaje przycisk o niestandardowym wyglądzie (Text jako przycisk).
     * @param {String} tekst - Napis na przycisku.
     * @param {Func} funkcjaKlikniecia - Funkcja wywoływana po kliknięciu (callback).
     * @param {String} [opcje=""] - Ciąg opcji AHK określający pozycję i wymiary (np. "x10 y10 w100 h40").
     * @param {Boolean} [ApplyScale=true] - Applies DPI scaling to options.
     * @param {Object} [Opt] - Opcje czcionki: {FontSize: SilnikGUI.Statics.GlobFont.Size, FontOpt: "", Pad: 4, PadX: 4, PadY: 4}.
     * @tag WinAPI: "IsSilnikInput" (dla przycisku i ramki).
     */
    DodajPrzycisk(tekst, funkcjaKlikniecia, opcje := "", ApplyScale := true, Opt?) {
        myRawOpt := Opt ?? {}
        myPad := myRawOpt.HasProp("Pad") ? myRawOpt.Pad : 4
        myPadX := myRawOpt.HasProp("PadX") ? myRawOpt.PadX : myPad
        myPadY := myRawOpt.HasProp("PadY") ? myRawOpt.PadY : myPad
        Opt := Utils.MergeOptions(myRawOpt, { FontSize: SilnikGUI.Statics.GlobFont.Size, FontOpt: "", Pad: myPad, PadX: myPadX, PadY: myPadY })

        if (ApplyScale)
            opcje := Utils.ScaleOptions(opcje)
        Skala := (A_ScreenDPI / 96) * SilnikGUI.Statics.TotalScale
        Grubosc := ApplyScale ? Round(2 * Skala) : 2

        ; 1. DUMMY: Rezerwacja przestrzeni w layoucie (Bounding Box)
        ; Tworzymy ukryty element, aby AHK przeliczył pozycje (xm, yp itp.) i wymiary
        dummy := this.Stan.ChildGui.Add("Text", opcje . " Hidden", tekst)
        dummy.IsDummy := true
        dummy.GetPos(&dX, &dY, &dW, &dH)

        wymBtn := SilnikGUI.ZmierzTekst(tekst, SilnikGUI.Statics.GlobFont.Name, "s" . Round(Opt.FontSize * SilnikGUI.Statics.TotalScale) . " " . Opt.FontOpt)
        reqW := wymBtn.w + Round(Opt.PadX * Skala) + (2 * Grubosc)
        reqH := wymBtn.h + Round(Opt.PadY * Skala) + (2 * Grubosc)

        zmianaWymiaru := false
        if !RegExMatch(opcje, "i)\bw-?\d+") {
            dW := Max(reqW)
            zmianaWymiaru := true
        }
        if !RegExMatch(opcje, "i)\bh-?\d+") {
            dH := Max(reqH)
            zmianaWymiaru := true
        }
        if (zmianaWymiaru)
            dummy.Move(, , dW, dH)

        ; 2. INSET: Obliczenie wymiarów wewnętrznych (Kompensacja ramki)
        ; Przycisk musi być mniejszy o grubość ramki, aby całość (Button+Ramka) miała wymiar Dummy
        iX := dX + Grubosc
        iY := dY + Grubosc
        iW := Max(1, dW - (2 * Grubosc)) ; Zabezpieczenie min. 1px
        iH := Max(1, dH - (2 * Grubosc))

        ; 3. WŁAŚCIWY PRZYCISK (Pozycjonowanie absolutne wewnątrz Dummy)
        btn := this.Stan.ChildGui.Add("Text", "x" . iX . " y" . iY . " w" . iW . " h" . iH . " Center Background" . SilnikGUI.Motyw.Przycisk . " " . SilnikGUI.Motyw.Tekst . " +0x0200 +0x100 +Tabstop", tekst)
        btn.SetFont("s" . Round(Opt.FontSize * SilnikGUI.Statics.TotalScale) . " " . Opt.FontOpt, SilnikGUI.Statics.GlobFont.Name)
        this.Stan.Kontrolki.Push(btn) ; [FIX] Rejestracja w systemie (dla Ramka i stylów)

        ; [MOD] Wrapper Multiklik: Flash + Callback
        ActionWrapper := (ctrl, *) => (SilnikGUI.CzyMoznaInterakcja(ctrl) && (SilnikGUI.EfektFlash(ctrl, 150), funkcjaKlikniecia(ctrl, 0)))
        ; [MOD] Bezpośrednia akcja na wciśnięcie
        btn.MouseDownAction := ActionWrapper

        ; Oznacz jako CustomButton (dla fokusu)
        btn.Rola := "CustomButton"
        btn.GruboscRamki := Grubosc ; Cache dla logiki

        ; Obsługa Enter
        btn.OnEnter := (ctrl) => ctrl.MouseDownAction()

        ; 4. RAMKA (Rysowana na zewnątrz przycisku -> Pokrywa się z krawędziami Dummy)
        ; Margin=0, ponieważ kompensację zrobiliśmy ręcznie w kroku 2
        ramkaObj := this.Ramka(btn, 0, 0, "", Grubosc, , 0)

        ; Powiązania dla MonitorujStan (Podświetlanie całej grupy)
        ramkaObj.ParentCtrl := btn
        btn.Ramka := ramkaObj

        ; [TAGOWANIE WinAPI]
        Utils.SetTag(btn.Hwnd, "IsSilnikInput")
        for c in ramkaObj.Ctrls
            Utils.SetTag(c.Hwnd, "IsSilnikInput")

        return SilnikGUI.GrupaKontrolek([btn], [btn, ramkaObj])
    }

    /**
     * Metoda wewnętrzna: Dynamicznie dostosowuje szerokość okna i pola do zawartości.
     * Wywoływana automatycznie, gdy SzerPola=0 w DodajWierszKonfiguracji.
     * @param {Integer} SzerEtykiety - Szerokość etykiety (stała).
     * @param {Gui.Edit} ctrl - Kontrolka Edit, której rozmiar ma być dostosowany.
     * @param {Integer} [MinW = 50] - Minimalna szerokość kontrolki.
     * @param {Integer} [MinH = 18] - Minimalna wysokość kontrolki.
     */
    DostosujRozmiar(SzerEtykiety, ctrl, MinW := 50, MinH := 18, *) {
        fName := HasProp(ctrl, "FontName") ? ctrl.FontName : SilnikGUI.Statics.GlobFont.Name
        fSize := HasProp(ctrl, "FontSize") ? ctrl.FontSize : SilnikGUI.Statics.GlobFont.Size
        FinalSize := Round(fSize * SilnikGUI.Statics.TotalScale)
        hWiersza := HasProp(ctrl, "WysWiersza") ? ctrl.WysWiersza : 18

        ; 2. Grubość z cache
        Grubosc := HasProp(ctrl, "GruboscRamki") ? ctrl.GruboscRamki : Round(2 * ((A_ScreenDPI / 96) * SilnikGUI.Statics.TotalScale))

        ; BazoweX (domyślnie 10)
        MargL := HasProp(ctrl, "BazoweX") ? ctrl.BazoweX : 10
        MargP := this.Stan.PadR
        RamkaOkna := this.Stan.GruboscRamki

        this.GuiObj.GetClientPos(, , &cw, &ch)

        phW_main := 0
        if HasProp(ctrl, "PlaceholderCtrl")
            ctrl.PlaceholderCtrl.GetPos(, , &phW_main)

        ; 1. [Matematyczny Kaganiec] Obliczenie twardego limitu dla kontrolki
        LimitOkna := (this.Stan.AutoFitW > 0) ? ((this.Stan.AutoFitW > 1) ? this.Stan.AutoFitW : Round(A_ScreenWidth * this.Stan.AutoFitW)) : (cw > 0 ? cw : A_ScreenWidth)
        Overhead := MargL + MargP + (2 * RamkaOkna) + SzerEtykiety + (2 * Grubosc) + phW_main
        MaxMiejsceDlaEdita := LimitOkna - Overhead

        wymCtrl := SilnikGUI.ZmierzTekst(ctrl.Value, fName, "s" . FinalSize)
        wAktualne := wymCtrl.w + Round(FinalSize) + 12 ; Zapas na marginesy wewnętrzne Edit i karetkę

        if !(HasProp(ctrl, "ResizeEditW") && ctrl.ResizeEditW)
            wAktualne := MinW
        wAktualne := Min(wAktualne, MaxMiejsceDlaEdita)
        wAktualne := Max(wAktualne, MinW) ; Bezpiecznik minimalny

        ; [FIX] Drugi pomiar wysokości z narzuconą szerokością (Edit dla word-wrap bez spacji)
        wymJednejLinii := SilnikGUI.ZmierzTekst("W", fName, "s" . FinalSize)
        wymWrap := SilnikGUI.ZmierzTekst(ctrl.Value, fName, "s" . FinalSize, wAktualne)
        lines := Max(1, Ceil(wymWrap.h / wymJednejLinii.h))
        WysokoscLayout := lines * hWiersza

        if !(HasProp(ctrl, "ResizeEditH") && ctrl.ResizeEditH)
            WysokoscLayout := MinH
        WysokoscLayout := Max(WysokoscLayout, MinH) ; Zabezpieczenie minimalnej wysokości

        ; 3. Nowa szerokość (Etykieta+Input+Ramka)
        SzerKontr := SzerEtykiety + wAktualne + (2 * Grubosc) + phW_main

        ; Min zawartość (Marginesy+Kontrolka+Ramki)
        NowaSzer := MargL + SzerKontr + MargP + (2 * RamkaOkna)

        ; 4. Resize okna/kontrolki
        this.GuiObj.GetPos(&x, &y, &w, &h)

        if (HasProp(this.Stan, "MinW") && this.Stan.MinW > NowaSzer)
            NowaSzer := this.Stan.MinW

        if (this.CallbackLayout)
            this.CallbackLayout.Call(NowaSzer - (2 * RamkaOkna), (this.Stan.CzyPokazano && !this.Stan.UseChild) ? RamkaOkna : 0, WysokoscLayout, hWiersza)

        ; [FIX] Dynamiczne obliczanie bezpiecznej szerokości na podstawie INNYCH kontrolek
        ; Zapobiega ucinaniu statycznej treści przy zwężaniu, ale pozwala na shrink (kurczenie).
        SafeContent := this.ObliczObszarRoboczy(ctrl)

        extraFrame := (this.Stan.UseChild && RamkaOkna > 0) ? (2 * RamkaOkna) : 0
        NowaSzer := Max(NowaSzer, MinW, SafeContent.W + extraFrame)
        NowaSzer := Min(NowaSzer, LimitOkna) ; Kaganiec na całe okno

        DiffW := w - cw
        DiffH := h - ch

        TargetW := Round(NowaSzer + DiffW)

        if (TargetW & 1)
            TargetW++ ; [FIX] Wymuś parzystość szerokości (eliminuje drift środka przy nieparzystych przyrostach)


        ; [FIX] Masowe pozycjonowanie wszystkich dynamicznych kontrolek.
        ; Zapewnia, że inne wiersze AutoCenter dostosują się do nowej szerokości okna.
        for c in this.Stan.Kontrolki {
            if !(c.Type = "Edit" && HasProp(c, "CzyDynamiczne") && c.CzyDynamiczne)
                continue

            cfName := HasProp(c, "FontName") ? c.FontName : SilnikGUI.Statics.GlobFont.Name
            cfSize := HasProp(c, "FontSize") ? c.FontSize : SilnikGUI.Statics.GlobFont.Size

            cFinalSize := Round(cfSize * SilnikGUI.Statics.TotalScale)

            cGrubosc := HasProp(c, "GruboscRamki") ? c.GruboscRamki : Round(2 * ((A_ScreenDPI / 96) * SilnikGUI.Statics.TotalScale))
            cMargL := HasProp(c, "BazoweX") ? c.BazoweX : 10
            cSzerEtykiety := HasProp(c, "SzerEtykiety") ? c.SzerEtykiety : 0
            cSzerPola := HasProp(c, "SzerPola") ? c.SzerPola : MinW
            cWysInput := HasProp(c, "WysInput") ? c.WysInput : MinH

            cPhW := 0
            if HasProp(c, "PlaceholderCtrl")
                c.PlaceholderCtrl.GetPos(, , &cPhW)

            cOverhead := cMargL + MargP + (2 * RamkaOkna) + cSzerEtykiety + (2 * cGrubosc) + cPhW

            wymC := SilnikGUI.ZmierzTekst(c.Value, cfName, "s" . cFinalSize)
            cwAktualne := wymC.w + Round(cFinalSize) ; Zapas na marginesy wewnętrzne Edit i karetkę

            if !(HasProp(c, "ResizeEditW") && c.ResizeEditW)
                cwAktualne := cSzerPola
            cwAktualne := Min(cwAktualne, LimitOkna - cOverhead)
            cwAktualne := Max(cwAktualne, cSzerPola)

            chWiersza := HasProp(c, "WysWiersza") ? c.WysWiersza : 18
            ; [FIX] Drugi pomiar wysokości dla pozostałych kontrolek w trybie word-wrap Edit
            wymJednejLiniiC := SilnikGUI.ZmierzTekst("W", cfName, "s" . cFinalSize)
            wymWrapC := SilnikGUI.ZmierzTekst(c.Value, cfName, "s" . cFinalSize, cwAktualne)
            linesC := Max(1, Ceil(wymWrapC.h / wymJednejLiniiC.h))
            cWysokoscLayout := linesC * chWiersza

            if !(HasProp(c, "ResizeEditH") && c.ResizeEditH)
                cWysokoscLayout := cWysInput
            cWysokoscLayout := Max(cWysokoscLayout, cWysInput)

            cSzerKontr := cSzerEtykiety + cwAktualne + (2 * cGrubosc) + cPhW

            cDynX := cMargL
            if (HasProp(c, "AutoCenter") && c.AutoCenter) {
                cOffsetCentrowania := ((NowaSzer - (RamkaOkna * 2) - cMargL - MargP) - cSzerKontr) / 2
                cDynX := Max((cMargL + Round(cOffsetCentrowania)), cMargL)
            }
            cFinalneX := Round(cDynX)

            cInfoRight := HasProp(c, "InfoRight") ? c.InfoRight : 0
            if (cInfoRight) {
                cX_Grupy := cFinalneX
                if HasProp(c, "EtykietaCtrl")
                    c.EtykietaCtrl.Move(cFinalneX + cwAktualne + (2 * cGrubosc) + cPhW + 10)
            } else {
                cX_Grupy := cFinalneX + cSzerEtykiety
                if HasProp(c, "EtykietaCtrl")
                    c.EtykietaCtrl.Move(cFinalneX)
            }

            if HasProp(c, "Ramka") {
                c.GetPos(, &cyCtrl)
                cyRamki := cyCtrl - cGrubosc

                c.Move(cX_Grupy + cGrubosc, cyCtrl, cwAktualne, cWysokoscLayout)
                c.Ramka.Move(cX_Grupy, cyRamki, cwAktualne + (2 * cGrubosc), cWysokoscLayout + (2 * cGrubosc))
                c.Ramka.Redraw()
                if HasProp(c, "PlaceholderCtrl")
                    c.PlaceholderCtrl.Move(cX_Grupy + cwAktualne + (2 * cGrubosc), cyRamki, cPhW, cWysokoscLayout + (2 * cGrubosc))
            } else {
                c.GetPos(, &cyCtrl)
                c.Move(cX_Grupy, , cwAktualne, cWysokoscLayout)
                if HasProp(c, "PlaceholderCtrl")
                    c.PlaceholderCtrl.Move(cX_Grupy + cwAktualne, cyCtrl, cPhW, cWysokoscLayout)
            }
        }

        ; 4. Callback układu
        if (this.CallbackLayout) {
            SzerokoscLayout := NowaSzer - (2 * RamkaOkna)
            OffsetLayout := (this.Stan.CzyPokazano && !this.Stan.UseChild) ? RamkaOkna : 0
            if (!this.Stan.LastLayoutState || this.Stan.LastLayoutState.W != SzerokoscLayout || this.Stan.LastLayoutState.Off != OffsetLayout || this.Stan.LastLayoutState.H != WysokoscLayout) {
                this.CallbackLayout.Call(SzerokoscLayout, OffsetLayout, WysokoscLayout, hWiersza)
                this.Stan.LastLayoutState := { W: SzerokoscLayout, Off: OffsetLayout, H: WysokoscLayout }
            }
        }

        ; [FIX] 5. Obliczenie nowej wysokości okna (AutoFitH) i łączony Resize
        TargetH := h
        this.Stan.LastObszarTick := 0 ; Wymuszenie czyszczenia cache po zmianach układu
        if (this.Stan.AutoFitH > 0) {
            ContentAfter := this.ObliczObszarRoboczy()
            NowaWys := ContentAfter.H + extraFrame
            LimitOknaH := (this.Stan.AutoFitH > 1) ? this.Stan.AutoFitH : Round(A_ScreenHeight * this.Stan.AutoFitH)
            NowaWys := Min(NowaWys, LimitOknaH)
            TargetH := Round(Max(NowaWys + DiffH, 50)) ; Bezpieczne minimum
        }

        if (this.Stan.CzyPokazano) {
            finalW := (this.Stan.AutoFitW > 0 && this.Stan.AutoFitW <= 1) ? TargetW : w
            finalH := (this.Stan.AutoFitH > 0 && this.Stan.AutoFitH <= 1) ? TargetH : h
            if (w != finalW || h != finalH) {
                NoweX := x + Integer((w - finalW) / 2)
                this.GuiObj.Move(NoweX, y, finalW, finalH)
            } else if (this.Stan.UseChild && (this.Stan.AutoFitW > 0 || this.Stan.AutoFitH > 0)) {
                this.AktualizujLayout(cw, ch)
                this.WymusPelnyRedraw()
            }
        }
    }

    /**
     * @desc Zamyka aktywne popupy (np. podczas ręcznego scrollowania).
     */
    ZamknijPopupy() {
        if (this.Stan.PopupActive && this.Stan.HasProp("PopupGuiObj") && this.Stan.PopupGuiObj && HasProp(this.Stan.PopupGuiObj, "Zamknij"))
            this.Stan.PopupGuiObj.Zamknij()
        for dziecko in this.Stan.Dzieci
            dziecko.ZamknijPopupy()
    }

    ; Zaślepki dla analizatora statycznego VSC (implementacja w klasie dziedziczącej SilnikGUI)
    AktualizujLayout(w, h, start := 0) {
    }
    WymusPelnyRedraw() {
    }
}

/**
 * 5. WARSTWA PANELI (SUBWINDOWS)
 * Zarządzanie zagnieżdżonymi oknami i panelami roboczymi.
 */
class SubWindows extends CtlFactory {
    /**
     * Tworzy zagnieżdżony Panel (bez wyświetlania).
     * @param {Integer} [GruboscRamki=2] - Grubość ramki.
     * @param {Integer} [CSBarV=1] - Czy pokazać pasek przewijania pionowego (1 lub 0).
     * @param {Integer} [CSBarH=1] - Czy pokazać pasek przewijania poziomego (1 lub 0).
     * @param {Object} [opcjePanela=""] - Dodatkowe parametry dla silnika panelu.
     * @tag WinAPI: "IsSilnikPanel" (dla GuiObj oraz ChildGui/ClipGui panelu).
     * @returns {SilnikGUI}
     */
    DodajPanel(GruboscRamki := 2, CSBarV := 1, CSBarH := 1, opcjePanela := "") {
        opcje := Utils.MergeOptions(opcjePanela, { pokazPasek: 0, createChild: true, zamknijNaEsc: 0, CSBarV: CSBarV, CSBarH: CSBarH, ResizeMarg: 0, GruboscRamki: 0, dragBezPaska: 0, RamkaPanelu: GruboscRamki })
        ChildPanel := SilnikGUI("PANEL_" . this.GuiObj.Hwnd, "-Border +Parent" . this.Stan.ChildGui.Hwnd . " +AlwaysOnTop +E0x10000", opcje)

        this.Stan.Dzieci.Push(ChildPanel)
        EscAction := (*) => this.Zakoncz()
        ChildPanel.GuiObj.OnEvent("Escape", EscAction)
        ChildPanel.Stan.ChildGui.OnEvent("Escape", EscAction)
        ChildPanel.Stan.ClipGui.OnEvent("Escape", EscAction)
        ChildPanel.IsPanel := true

        ; [TAGOWANIE WinAPI]
        Utils.SetTag(ChildPanel.GuiObj.Hwnd, "IsSilnikPanel")
        if (ChildPanel.Stan.UseChild) {
            Utils.SetTag(ChildPanel.Stan.ClipGui.Hwnd, "IsSilnikPanel")
            Utils.SetTag(ChildPanel.Stan.ChildGui.Hwnd, "IsSilnikPanel")
        }
        return ChildPanel
    }

    /**
     * Wyświetla panel jako okno zagnieżdżone i synchronizuje go z układem rodzica. Zaawansowane opcje we właściwościach obiektu
     * @param {SilnikGUI} RodzicPanelu - Instancja silnika nadrzędnego.
     * @param {String} [pozycja="xm"] - Pozycja wewnątrz rodzica.
     * @param {Object} [opcje=""] - Opcje dla metody Pokaz
     * @param {Boolean} [ApplyScale=true] - Applies DPI scaling to options.
     * @tag WinAPI: "IsSilnikPanel" (dla zastępczego DummyCtrl i ramki).
     */
    PokazPanel(RodzicPanelu, pozycja := "xm", opcje := "", ApplyScale := true) {
        this.Pokaz(opcje)
        this.GuiObj.GetClientPos(, , &wPanel, &hPanel)
        Skala := 1 / ((A_ScreenDPI / 96) * SilnikGUI.Statics.TotalScale)

        if !HasProp(this, "DummyCtrl") {
            gRamki := this.Stan.RamkaPanelu ? this.Stan.RamkaPanelu : this.Stan.GruboscRamki
            myScaledPos := ApplyScale ? Utils.ScaleOptions(pozycja) : pozycja
            this.DummyCtrl := RodzicPanelu.Add("Text", myScaledPos . " w" . wPanel . " h" . hPanel . " BackgroundTrans", "", false)
            this.DummyCtrl.GetPos(&cX, &cY)
            this.DummyCtrl.Move((cX + gRamki) * Skala, (cY + gRamki) * Skala) ; Korekta o grubość ramki

            this.DummyCtrl.PanelObj := this
            this.DummyCtrl.Rola := "Panel"

            this.DummyCtrl.DefineProp("Move", { Call: (ctrl, p*) => (
                ctrl.GetPos(&oldX, &oldY),
                Gui.Control.Prototype.Move.Call(ctrl, p*),
                ctrl.GetPos(&cX, &cY),
                ctrl.PanelObj.GuiObj.Move(cX, cY),
                ctrl.PanelObj.PrzesunPopupy(cX - oldX, cY - oldY)
            ) })
            this.DummyCtrl.Ramka := RodzicPanelu.Ramka(this.DummyCtrl, 0, 0, "", gRamki, , 0)
            this.DummyCtrl.Ramka.ParentCtrl := this.DummyCtrl
            this.DummyCtrl.MouseDownAction := (ctrl, *) => DllCall("SetFocus", "Ptr", ctrl.PanelObj.Stan.FocusSink.Hwnd)

            ; [TAGOWANIE WinAPI]
            Utils.SetTag(this.DummyCtrl.Hwnd, "IsSilnikPanel")
            for c in this.DummyCtrl.Ramka.Ctrls
                Utils.SetTag(c.Hwnd, "IsSilnikPanel")
        } else {
            this.DummyCtrl.Move(, , , wPanel, hPanel)
        }

        this.DummyCtrl.GetPos(&dX, &dY)
        this.GuiObj.Move(dX, dY)
    }

    /**
     * @desc Tworzy panel tekstowy z wbudowanym Edit i placeholderem paska przewijania.
     * @param {String} tekst - Treść pola.
     * @param {Integer} w - Szerokość okna panelu.
     * @param {Integer} h - Wysokość okna panelu.
     * @param {Object} [opcje] - Konfiguracja.
     * - [pozycja="xm"] {String} - Pozycja panelu względem rodzica (np. "x10 y10", "xm", "ym").
     * - [gruboscRamki=2] {Integer} - Grubość ramki panelu.
     * - [InfiniteLine=false] {Boolean} - Czy panel ma być nieskończoną linią (rozciągać się na całą szerokość).
     * - [BackCol=SilnikGUI.Motyw.Wklesly] {String} - Kolor tła panelu (np. "#FFFFFF" lub nazwa z motywu).
     * - [TextCol=SilnikGUI.Motyw.Tekst] {String} - Kolor tekstu w polu.
     * - [FontName=SilnikGUI.Statics.GlobFont.Name] {String} - Nazwa czcionki.
     * - [FontSize=SilnikGUI.Statics.GlobFont.Size] {Integer} - Rozmiar czcionki w pkt.
     * - [Backlight=0] {Integer} - Poziom podświetlenia (0 = brak, 1 = delikatne, 2 = mocne).
     * - [ApplyScale=true] {Boolean} - Applies DPI scaling to options.
     * @tag WinAPI: "IsSilnikPanel" (panel) oraz "IsSilnikInput" (pole tekstowe).
     * @return {SilnikGUI} - Instancja utworzonego sub-panelu.
     */
    DodajPanelTxt(tekst, w, h, opcje?) {
        opcje := Utils.MergeOptions(opcje?, { pozycja: "xm", gruboscRamki: 2, InfiniteLine: false, BackCol: SilnikGUI.Motyw.Wklesly, TextCol: SilnikGUI.Motyw.Tekst, FontName: SilnikGUI.Statics.GlobFont.Name, FontSize: SilnikGUI.Statics.GlobFont.Size, Backlight: 0, ApplyScale: true })
        pozycja := opcje.pozycja, gruboscRamki := opcje.gruboscRamki, infLine := opcje.InfiniteLine, FontName := opcje.FontName, FontSize := opcje.FontSize, Backlight := opcje.Backlight, ApplyScale := opcje.ApplyScale
        BackCol := SilnikGUI.PobierzHex(opcje.BackCol), TextCol := "c" . SilnikGUI.PobierzHex(opcje.TextCol)

        p := this.DodajPanel(gruboscRamki, 1, infLine ? 1 : 0, { PadR: 0, PadD: 0, AutoFitW: infLine ? 999999 : 0, AutoFitH: 999999 })
        bs := p.Stan.VBar.BarSize

        opcjeWiersza := { trybWalidacji: 3, pozycja: "x0 y0", ResizeEditW: infLine, ResizeEditH: true, SzRamki: 0, AutoCenter: false, EditOpt: "Left", FontName: FontName, FontSize: FontSize, BackCol: BackCol, TextCol: TextCol, Backlight: Backlight }

        Skala := (A_ScreenDPI / 96) * SilnikGUI.Statics.TotalScale
        wFizyczne := ApplyScale ? Round(w * Skala) : w
        hFizyczne := ApplyScale ? Round(h * Skala) : h

        opcjeWiersza.SzerPola := Max(10, wFizyczne - (infLine ? 0 : (bs + p.Stan.RamkaPanelu)))
        opcjeWiersza.WysPola := Max(10, hFizyczne)
        opcjeWiersza.ApplyScale := false

        editGrp := p.DodajWierszKonfiguracji("", tekst, opcjeWiersza)
        editGrp.MainCtrl.FlexH := infLine

        if !infLine {
            ph := p.Add("Text", "x0 y0 w" (bs + gruboscRamki) " +0x100 Background" BackCol)
            ph.Rola := "Placeholder"
            if Backlight == 1
                ph.KolorBazowy := BackCol
            ph.ParentCtrl := editGrp.MainCtrl
            editGrp.MainCtrl.PlaceholderCtrl := ph
        }

        editGrp.MainCtrl.SledzKaretke := true
        editGrp.MainCtrl.OnEvent("Change", (c, *) => SetTimer(ObjBindMethod(p, "SledzKaretke", c), -10))

        ; [FIX] Ręczne przypisanie właściwości zapobiega awarii RegExMatch w metodzie Pokaz()
        p.PokazPanel(this, pozycja, "w" w " h" h, ApplyScale)
        return p
    }
    ;zaslepka dla  VSC
    __New(p*) {
    }
    Zakoncz() {
    }
    Pokaz(opcje?) {
    }


}

/**
 * 6. KLASA GŁÓWNA (FINALNA)
 * Klasa SilnikGUI - Modyfikowalny silnik do tworzenia okien konfiguracyjnych.
 * Opiera się na stylach i funkcjach z mouse_ctrl.ahk (ciemny motyw, ramki, walidacja).
 */
class SilnikGUI extends SubWindows {

    /**
     * Tworzy nowe okno GUI z zadanym tytułem i stylem.
     * @param {String} tytul - Tytuł okna.
     * @param {String} [opcje=""] - Dodatkowe opcje GUI: +AlwaysOnTop, MinSize[W]x[H]
     * @param {Object} [parametry] - Opcjonalny obiekt konfiguracyjny z parametrami:
     * - [unikalny: false] {Boolean|String} - Singleton. true = użyj tytułu okna jako ID, String = własne ID.
     * - [pokazPasek: 1] {Integer} - 0 = Brak paska (Borderless), 1 = Pasek widoczny.
     * - [createChild: true] {Boolean} - Czy tworzyć warstwę kontrolek (ChildGui).
     * - [zamknijNaEsc: 1] {Integer} - Akcja ESC: 0=Off, 1=Hide, 2=Destroy.
     * - [CSBarV: 1] {Integer} - Czy pokazać pasek przewijania pionowego (1 lub 0).
     * - [CSBarH: 1] {Integer} - Czy pokazać pasek przewijania poziomego (1 lub 0).
     * - [ResizeMarg: 6] {Integer} - Margines aktywujący zmianę rozmiaru (Borderless).
     * - [GruboscRamki: 2] {Integer} - Grubość ramki (jeśli pokazPasek=0).
     * - [dragBezPaska: 1] {Integer} - Czy umożliwić przeciąganie okna bez paska (1 lub 0).
     * - [MainGUI: false] {Boolean|Function} - Zamyka wszystkie inne instancje SilnikGUI i ubija skrypt: [true] - po posprzątaniu mechanizmów SilnikGUI skrypt zostanie zakmniety prostym ExitApp, [function] - callback po zamknięciu okien -jeśli twój skrypt  ma własny  mechanimz zamykania, podaj go tu, zostanie wykonany po posprzątaniu SilnikGUI)
     * - [RamkaPanelu: 2] {Integer} - Wewnętrzny odstęp paneli.
     * - [PadL: 0] {Integer} - Margines z lewej strony.
     * - [PadR: 0] {Integer} - Margines z prawej strony.
     * - [PadD: 0] {Integer} - Margines od dołu.
     * - [AutoFitW: 0] {Number} - Dopasowanie szerokości.
     * - [AutoFitH: 0] {Number} - Dopasowanie wysokości.
     * - [Transparent: 0] {Integer} - Przezroczystość okna (0.0-1.0).
     */
    static Call(tytul, opcje := "", parametry?) { ; metoda bezpiecznikowa (Singleton) antydubel, rzeczywisty konstruktor to drugi "_New"
        id := (IsSet(parametry) && parametry.HasOwnProp("unikalny") && parametry.unikalny) ? (parametry.unikalny = 1 ? tytul : parametry.unikalny) : false
        if (id && this.Statics.unikalneInstancje.Has(id) && (inst := this.Statics.unikalneInstancje[id]) && inst.GuiObj && WinExist("ahk_id " inst.GuiObj.Hwnd)) {
            inst.nowaInstancja := false
            return inst
        }
        inst := super.Call(tytul, opcje, parametry?)
        inst.nowaInstancja := true
        if (id)
            this.Statics.unikalneInstancje[id] := inst
        return inst
    }


    ; Statyczny inicjalizator: Wymusza DPI Awareness V2 dla wątku
    static __New() {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
        ; [FIX] Przejście na pasywny nasłuch komunikatów (likwiduje konflikt z Hookiem mouse_ctrl)
        OnMessage(0x020A, (w, l, m, h) => this.ObslugaZdarzenSystemowych(w, l, m, h)) ; WM_MOUSEWHEEL
        OnMessage(0x020E, (w, l, m, h) => this.ObslugaZdarzenSystemowych(w, l, m, h)) ; WM_MOUSEHWHEEL
        OnMessage(0x0100, (w, l, m, h) => this.ObslugaZdarzenSystemowych(w, l, m, h)) ; WM_KEYDOWN
        OnMessage(0x0104, (w, l, m, h) => this.ObslugaZdarzenSystemowych(w, l, m, h)) ; WM_SYSKEYDOWN
        OnMessage(0x0207, (w, l, m, h) => this.ObslugaZdarzenSystemowych(w, l, m, h)) ; WM_MBUTTONDOWN
        OnMessage(0x0208, (w, l, m, h) => this.ObslugaZdarzenSystemowych(w, l, m, h)) ; WM_MBUTTONUP
        OnMessage(0x0020, (w, l, m, h) => this.ObslugaZdarzenSystemowych(w, l, m, h)) ; WM_SETCURSOR
        ; [FIX] Wrapper Lambda dla OnMessage (rozwiązuje błąd "Invalid callback function")
        Callback := (w, l, m, h) => this.ObslugaInterakcji(w, l, m, h)
        OnMessage(0x0201, Callback)
        OnMessage(0x0203, Callback)
        ; [FIX] WM_MOUSEACTIVATE: Zwróć MA_NOACTIVATE (3) dla okien z flagą WS_EX_NOACTIVATE
        OnMessage(0x0021, (w, l, m, h) => (WinExist("ahk_id " h) && (WinGetExStyle("ahk_id " h) & 0x08000000)) ? 3 : "")

        ; [STRATEGIA 1] Pre-Kalkulacja layoutu
        OnMessage(0x0046, (w, l, m, h) => this.ObslugaZmianyRozmiaruSystem(w, l, m, h)) ; WM_WINDOWPOSCHANGING
        OnMessage(0x0047, (w, l, m, h) => this.ObslugaZmianyRozmiaruSystem(w, l, m, h)) ; WM_WINDOWPOSCHANGED

        SetTimer(ObjBindMethod(this, "GłównaPętlaStanu"), SilnikGUI.TickRate)
    }

    /**
     * Scentralizowana pętla stanu dla wszystkich instancji.
     * Rozwiązuje problem konfliktów Timerów (Race Conditions).
     */
    static GłównaPętlaStanu() {
        static LastRoutedHwnd := 0 ; Cache stabilnego uchwytu
        MouseGetPos(&mx, &my, &win, &hitHwndRaw, 2)
        try foc := ControlGetFocus("A")
        catch
            foc := 0
        IsLBtn := GetKeyState("LButton", "P")

        isScrolling := (A_TickCount - SilnikGUI.Statics.OstatniScrollTick < 150)
        hitHwnd := hitHwndRaw

        if (!isScrolling) {
            Detekcja := SilnikGUI.ObslugaInterakcji(0, 0, 0, hitHwndRaw, true)
            if (GetKeyState("Shift", "P") && Detekcja && !HasProp(Detekcja, "IsScrollbar") && HasProp(Detekcja, "ScrollAction"))
                Detekcja := 0
            ; [FIX] Uwzględnij blokadę przez maskę (gdy Detekcja = 0)
            hitHwnd := IsObject(Detekcja) ? Detekcja.Hwnd : Detekcja
            LastRoutedHwnd := hitHwnd
        } else {
            hitHwnd := LastRoutedHwnd ; Zamraża hover podczas scrolla
        }

        for inst in SilnikGUI.Statics.AktywneInstancje {
            if (inst.GuiObj)
                inst.MonitorujStan(mx, my, win, hitHwnd, foc, IsLBtn)
        }
    }
    /**
     * @desc Pobiera wymiary tekstu korzystając z jednego globalnego obiektu w pamięci. 
     */
    static ZmierzTekst(tresc, fontName := "", fontOptions := "", maxWidth := 0) {
        if !this.Statics.HasProp("GlobalDummyGui") {
            this.Statics.GlobalDummyGui := Gui("-DPIScale")
            this.Statics.GlobalDummyTxt := this.Statics.GlobalDummyGui.Add("Text", "")
        }
        fName := fontName != "" ? fontName : this.Statics.GlobFont.Name
        this.Statics.GlobalDummyTxt.SetFont(fontOptions, fName)
        hDC := DllCall("GetDC", "Ptr", this.Statics.GlobalDummyTxt.Hwnd, "Ptr")
        hOldFont := DllCall("SelectObject", "Ptr", hDC, "Ptr", SendMessage(0x0031, 0, 0, this.Statics.GlobalDummyTxt.Hwnd), "Ptr")
        rect := Buffer(16, 0)
        flags := 0xC40 ; DT_CALCRECT | DT_EXPANDTABS | DT_NOPREFIX
        if (maxWidth > 0) {
            NumPut("Int", maxWidth, rect, 8) ; Set right border to maximum width
            flags |= 0x10 ; DT_WORDBREAK
        }
        DllCall("DrawText", "Ptr", hDC, "Str", tresc, "Int", -1, "Ptr", rect, "UInt", flags)
        DllCall("SelectObject", "Ptr", hDC, "Ptr", hOldFont)
        DllCall("ReleaseDC", "Ptr", this.Statics.GlobalDummyTxt.Hwnd, "Ptr", hDC)
        return { w: NumGet(rect, 8, "Int"), h: NumGet(rect, 12, "Int") }
    }

    /**
     * @desc Jawna inicjalizacja silnika (IoC) i rozgrzewka czcionek.
     * @param {String} [dodatkowySlownik=""] - Dodatkowe znaki klienta.
     * @param {Array} [opcjeCzcionek=[]] - Opcjonalne formaty (np. ["s12 bold"]).
     * @param {Array|String} [nazwyCzcionek=["Segoe UI"]] - Kroje czcionek do rozgrzania.
     */
    static InicjalizujSilnik(dodatkowySlownik := "", opcjeCzcionek := [], nazwyCzcionek := ["Segoe UI"]) {
        slownik := "💻✂🔍📄🡰🡲🡱🡳◑🔊🔉ψᛒ⊙🎧📞—✓▲▼◄►🞀❘❙❚🞂✲➠🡷🡵✍📸⚠️" . dodatkowySlownik
        wspolneOpcje := ["s9 norm", "s10 norm", "s13 w100", "s15 bold", "s20 norm"]
        for opcja in opcjeCzcionek
            wspolneOpcje.Push(opcja)
        for nazwa in (Type(nazwyCzcionek) == "Array" ? nazwyCzcionek : [nazwyCzcionek])
            for opcja in wspolneOpcje
                this.ZmierzTekst(slownik, nazwa, opcja)
    }

    /**
     * Centralna obsługa interakcji myszy i klawiatury.
     * Detekuje kontrolkę pod kursorem, obsługuje globalne skróty i chroni paski przewijania.
     * @param {Integer} wParam - Parametr WPARAM z komunikatu, nieużywany.
     * @param {Integer} lParam - Parametr LPARAM z komunikatu, nieużywany.
     * @param {Integer} msg - Komunikat Windows.
     * @param {Integer} hwnd - Uchwyt okna.
     * @param {Boolean} TylkoDetekcja - Czy tylko detekować kontrolkę.
     */
    static ObslugaInterakcji(wParam, lParam, msg, hwnd, TylkoDetekcja := false) {

        ; 1. Niskopoziomowy Raycast (WinAPI override, omija błędy 16-bit i maski)
        ctrl := 0
        if (hCtrl := SilnikGUI.GetRealHwndUnderMouse()) {
            try ctrl := GuiCtrlFromHwnd(hCtrl)
        }

        ; Omijamy router dla dwukliku w Edit (system zaznaczy słowo).
        ; Używamy try/hwnd bo MouseGetPos bywa ślepe na podwójne kliknięcia w zagnieżdżonych maskach.
        if (msg == 0x0203) {
            if (ctrl && ctrl.Type == "Edit")
                return
            try if (GuiCtrlFromHwnd(hwnd).Type == "Edit")
                return
        }

        ; [ROZWIĄZYWANIE CELU] Mapowanie czystych okien WinAPI (np. tło paska) na obiekty logiki
        Target := 0
        if (!ctrl && hCtrl) {
            try if ((g := GuiFromHwnd(hCtrl)) && HasProp(g, "Silnik")) {
                if (g.Silnik.Stan.VBar && g.Silnik.Stan.VBar.Hwnd == hCtrl)
                    Target := g.Silnik.Stan.VBar
                else if (g.Silnik.Stan.HBar && g.Silnik.Stan.HBar.Hwnd == hCtrl)
                    Target := g.Silnik.Stan.HBar
            }
        }

        ; 3. Propagacja do rodzica (dla etykiet, strzałek i ramek)
        if (!Target)
            Target := SilnikGUI.RozwiazKontrolke(ctrl, "MouseDownAction")

        if (TylkoDetekcja)
            return Target ? Target : (ctrl ? ctrl : hCtrl)

        ; [STRATEGIA 1] Centralne Zarządzanie Fokusem
        if (Target && !HasProp(Target, "IsScrollbar")) {
            focHwnd := 0
            try focHwnd := ControlGetHwnd(ControlGetFocus("A"), "A")

            if (focHwnd != Target.Hwnd)
                try Target.Focus()

            ; Prewencja Select-All i kierowanie karetką wg źródła kliknięcia
            if (Target.Type == "Edit" && ctrl != Target && (focHwnd != Target.Hwnd)) { ;
                pos := HasProp(Target, "LastCaretPos") ? Target.LastCaretPos : (((HasProp(Target, "PlaceholderCtrl") && ctrl == Target.PlaceholderCtrl) || HasProp(Target, "NativeEnter")) ? 0 : StrLen(Target.Value))
                SetTimer(PostMessage.Bind(0xB1, pos, pos, Target.Hwnd), -10)
            }
        } else if (!Target && (!ctrl || !HasProp(ctrl, "IsScrollbar"))) {
            hTarget := ctrl ? ctrl.Gui.Hwnd : hwnd
            curr := hTarget, found := false
            while (curr) {
                if ((g := GuiFromHwnd(curr)) && HasProp(g, "Silnik") && HasProp(g.Silnik.Stan, "FocusSink")) {
                    try g.Silnik.Stan.FocusSink.Focus(), found := true
                    break
                }
                curr := DllCall("GetAncestor", "Ptr", curr, "UInt", 1, "Ptr") ; GA_PARENT
            }
            if (!found)
                DllCall("SetFocus", "Ptr", hTarget)
        }

        if (Target)
            Target.MouseDownAction()

        return
    }

    /**
     * Obsługa zmian rozmiaru okna (WM_WINDOWPOSCHANGING i WM_WINDOWPOSCHANGED).
     * Pre-kalkulacja layoutu i optymalizacja redraw podczas resize.
     * @param {Integer} wParam - Parametr WPARAM z komunikatu, nieużywany.
     * @param {Integer} lParam - Parametr LPARAM z komunikatu, zawiera informacje o nowym rozmiarze i flagach.
     * @param {Integer} msg - Komunikat Windows (0x0046 lub 0x0047).
     * @param {Integer} hwnd - Uchwyt okna, używany do identyfikacji instancji SilnikGUI i zabezpieczenia przed rekurencją w ClipGui/ChildGui.
     */
    static ObslugaZmianyRozmiaruSystem(wParam, lParam, msg, hwnd) {
        if !(g := GuiFromHwnd(hwnd)) || !HasProp(g, "Silnik")
            return

        Silnik := g.Silnik

        ; [FIX] Blokada rekurencji: aktualizuj layout tylko dla głównego okna, ignoruj ClipGui/ChildGui
        if (!IsObject(Silnik.GuiObj) || hwnd != Silnik.GuiObj.Hwnd)
            return

        ; Zabezpieczenie przed x86 / x64 (Wskaźniki 4-bit vs 8-bit)
        flags := NumGet(lParam, (2 * A_PtrSize) + 16, "UInt")

        ; Ignoruj jeśli rozmiar się nie zmienia (SWP_NOSIZE)
        if (flags & 0x0001)
            return

        if (WinGetMinMax(hwnd) == -1)
            return

        w := NumGet(lParam, (2 * A_PtrSize) + 8, "Int")
        h := NumGet(lParam, (2 * A_PtrSize) + 12, "Int")

        if (msg == 0x0046) { ; WM_WINDOWPOSCHANGING (Pre-Factum)
            try {
                WinGetPos(, , &winW, &winH, hwnd)
                g.GetClientPos(, , &cliW, &cliH)
                clientW := w - (winW - cliW)
                clientH := h - (winH - cliH)
                if (Silnik.Stan.UseChild && clientW > 0 && clientH > 0)
                    Silnik.AktualizujLayout(clientW, clientH)
            }
        } else if (msg == 0x0047) { ; WM_WINDOWPOSCHANGED (Post-Factum)
            if !(WinGetStyle(hwnd) & 0xC00000)
                DllCall("RedrawWindow", "Ptr", hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0180)

            if (Silnik.Stan.DebounceRedraw)
                SetTimer(Silnik.Stan.DebounceRedraw, -50)
        }
    }

    ; główny konstruktor, dokumentacja w static Call
    __New(tytul, opcje := "", parametry?) {
        parametry := Utils.MergeOptions(parametry?, { pokazPasek: SilnikGUI.PokazPasek, createChild: SilnikGUI.UseChild, zamknijNaEsc: SilnikGUI.zamknijNaEsc, CSBarV: SilnikGUI.CSBarV, CSBarH: SilnikGUI.CSBarH, ResizeMarg: SilnikGUI.ResizeMarg, GruboscRamki: SilnikGUI.GruboscRamki, dragBezPaska: SilnikGUI.dragBezPaska, MainGUI: false, RamkaPanelu: SilnikGUI.RamkaPanelu, PadL: SilnikGUI.PadL, PadR: SilnikGUI.PadR, PadD: SilnikGUI.PadD, AutoFitW: SilnikGUI.AutoFitW, AutoFitH: SilnikGUI.AutoFitH, Transparent: 0.0 })
        pokazPasek := parametry.pokazPasek, createChild := parametry.createChild, zamknijNaEsc := parametry.zamknijNaEsc, CSBarV := parametry.CSBarV, CSBarH := parametry.CSBarH, ResizeMarg := parametry.ResizeMarg, GruboscRamki := parametry.GruboscRamki, dragBezPaska := parametry.dragBezPaska, MainGUI := parametry.MainGUI, RamkaPanelu := parametry.RamkaPanelu, PadL := parametry.PadL, PadR := parametry.PadR, PadD := parametry.PadD, AutoFitW := parametry.AutoFitW, AutoFitH := parametry.AutoFitH, Transparent := parametry.Transparent

        if !InStr(opcje, "-DPIScale")
            opcje .= " -DPIScale "
        if !InStr(opcje, "+0x02000000") {
            opcje .= " +0x02000000 " ; [FIX] WS_CLIPCHILDREN chroni przed migotaniem tła
        }
        if (pokazPasek == 0 && !InStr(opcje, "-Caption"))
            opcje .= " -Caption "

        Skala := (A_ScreenDPI / 96) * SilnikGUI.Statics.TotalScale

        this.Stan.UseChild := createChild
        this.Stan.CSBarV := CSBarV
        this.Stan.CSBarH := CSBarH
        this.Stan.PokazPasek := pokazPasek
        this.Stan.zamknijNaEsc := zamknijNaEsc
        this.Stan.ResizeMarg := Round(ResizeMarg * Skala)
        this.Stan.GruboscRamki := Round(GruboscRamki * Skala)
        this.Stan.dragBezPaska := dragBezPaska
        this.Stan.MainGUI := MainGUI
        this.Stan.RamkaPanelu := Round(RamkaPanelu * Skala)
        this.Stan.PadL := Round(PadL * Skala)
        this.Stan.PadR := Round(PadR * Skala)
        this.Stan.PadD := Round(PadD * Skala)
        this.Stan.AutoFitW := AutoFitW
        this.Stan.AutoFitH := AutoFitH
        this.Stan.MinW := RegExMatch(opcje, "i)MinSize\s*(\d+)", &m) ? Round(Integer(m[1]) * Skala) : 0


        this.GuiObj := Gui(opcje, tytul)
        this.GuiObj.Silnik := this ; [FIX] Referencja zwrotna dla ObslugaInterakcji
        this.GuiObj.BackColor := SilnikGUI.Motyw.Tlo
        this.GuiObj.SetFont("s" . Round(10 * SilnikGUI.Statics.TotalScale) . " " . SilnikGUI.Motyw.Tekst, SilnikGUI.Statics.GlobFont.Name)
        this.GuiObj.MarginX := this.Stan.PadL
        this.GuiObj.MarginY := 0

        if (Transparent != 0.0) {
            Transparent := Round(255 * (1.0 - Transparent))
            WinSetTransparent(Transparent, this.GuiObj.Hwnd)
        }
        ; Pochłaniacz fokusu (-Tabstop blokuje dotarcie klawiszem TAB)
        this.Stan.FocusSink := this.GuiObj.Add("Button", "x-10 y-10 w1 h1 -Tabstop")

        ; CHILD GUI (Kontener treści)
        if (this.Stan.UseChild) {
            ; [FIX] Viewport (Maska przycinająca) - Pośrednik między Parentem a Canvasem
            this.Stan.ClipGui := Gui("-Caption -Border +Parent" . this.GuiObj.Hwnd . " +E0x10000 +0x02000000 -DPIScale")
            this.Stan.ClipGui.BackColor := SilnikGUI.Motyw.Tlo
            this.Stan.ClipGui.MarginX := 0, this.Stan.ClipGui.MarginY := 0
            this.Stan.ClipGui.Silnik := this ; Przepięcie dla Raycastingu

            ; [FIX] +E0x10000 (WS_EX_CONTROLPARENT) - Umożliwia rekurencyjne tabowanie (wejście do kontenera)
            ; Parentem Childa jest teraz ClipGui, a nie GuiObj
            this.Stan.ChildGui := Gui("-Caption -Border +Parent" . this.Stan.ClipGui.Hwnd . " +E0x10000 +0x02000000 -DPIScale")
            this.Stan.ChildGui.BackColor := SilnikGUI.Motyw.Tlo
            this.Stan.ChildGui.SetFont("s" . Round(10 * SilnikGUI.Statics.TotalScale) . " " . SilnikGUI.Motyw.Tekst, SilnikGUI.Statics.GlobFont.Name)
            this.Stan.ChildGui.MarginX := this.Stan.PadL
            this.Stan.ChildGui.MarginY := 0
            this.Stan.ChildGui.Silnik := this

            ; [ETAP 2] Inicjalizacja Pasków (Ukryte na start)
            this.Stan.VBar := this.Stan.CSBarV ? SilnikGUI.PasekPrzewijania(this, "V") : 0
            this.Stan.HBar := this.Stan.CSBarH ? SilnikGUI.PasekPrzewijania(this, "H") : 0
            this.Stan.Corner := this.GuiObj.Add("Text", "x0 y0 w0 h0 Hidden Background" . SilnikGUI.Motyw.Tlo)
        }

        ; Motyw DWM (Pasek tytułu)
        SilnikGUI.UstawCiemnyMotywDWM(this.GuiObj.Hwnd, SilnikGUI.Motyw.Tryb)

        ; Zamknięcie (czyszczenie timerów)
        this.GuiObj.OnEvent("Close", (*) => this.Zakoncz())

        ; Obsługa ESC (0=Off, 1=Hide, 2=Destroy)
        if (zamknijNaEsc > 0) {
            EscAction := (zamknijNaEsc == 2 || MainGUI) ? (*) => this.Zakoncz() : (*) => this.GuiObj.Hide()
            this.GuiObj.OnEvent("Escape", EscAction)
            if (this.Stan.UseChild) {
                this.Stan.ClipGui.OnEvent("Escape", EscAction)
                this.Stan.ChildGui.OnEvent("Escape", EscAction)
            }
        }

        ; Monitor fokusu - obsługiwany statycznie przez GłównaPętlaStanu

        ; [FIX] Debounce Redraw (Naprawa artefaktów po resize)
        this.Stan.DebounceRedraw := ObjBindMethod(this, "WymusPelnyRedraw")

        hwnd := this.GuiObj.Hwnd
        if (this.Stan.PokazPasek == 0) {
            this.GuiObj.Opt(ResizeMarg > 0 ? "+Resize" : "-Resize")
            OnMessage(0x0083, (wp, lp, msg, hw) => (hw == hwnd) ? 0 : "")
            OnMessage(0x0084, ObjBindMethod(SilnikGUI, "ObslugaHitTest", hwnd, ResizeMarg))
            OnMessage(0x0086, (wp, lp, msg, hw) => (hw == hwnd) ? 1 : "") ;(Blokada paska)

            ; Przeciąganie dla okien bez paska
            if (this.Stan.dragBezPaska) {
                if !this.Stan.HandlerDrag {
                    this.Stan.HandlerDrag := this.ObslugaPrzeciaganiaBezPaska.Bind(this)
                    OnMessage(0x0201, this.Stan.HandlerDrag)
                    OnMessage(0x0203, this.Stan.HandlerDrag)
                }
            } else if (this.Stan.HandlerDrag) {
                OnMessage(0x0201, this.Stan.HandlerDrag, 0)
                OnMessage(0x0203, this.Stan.HandlerDrag, 0)
                this.Stan.HandlerDrag := 0
            }
        } else {
            this.GuiObj.Opt(ResizeMarg > 0 ? "+Resize" : "-Resize")
        }

        SilnikGUI.Statics.AktywneInstancje.Push(this) ; Rejestracja instancji do Raycastingu
    }

    /**
     * Wyświetla okno, umozliwia uzycie zmiennych PadD, PadR, (marinesy) AutoFitW, AutoFitH (procentowe lub pikselowe ograniczniki rozmiaru)
     * @param [Opt= ""] {String} Dodatkowe opcje dla metody Show (np. "w500 h300 NA").
     */
    Pokaz(Opt := "") {
        myDpiScale := (A_ScreenDPI / 96) * SilnikGUI.Statics.TotalScale

        ; Statyczna weryfikacja zdolności przyjmowania focusu (WS_TABSTOP = 0x10000)
        maTabstop := false
        skanujFocus(g) {
            for c in g
                if (c.Hwnd != this.Stan.FocusSink.Hwnd && (WinGetStyle(c.Hwnd) & 0x10000))
                    return true
            return false
        }
        this.Stan.FocusSink.Opt((skanujFocus(this.GuiObj) || (this.Stan.UseChild && skanujFocus(this.Stan.ChildGui))) ? "-Tabstop" : "+Tabstop")

        this.Stan.CzyPokazano := true ; Flaga wykonanego przesunięcia
        grubosc := this.Stan.GruboscRamki

        ; [FIX] Obejście marginesów (Resize OFF na czas pomiaru)
        hwnd := this.GuiObj.Hwnd
        styl := WinGetStyle(hwnd)

        ; [FIX] Odśwież dynamiczne (DostosujRozmiar + CallbackLayout) PRZED pomiarem AutoSize
        ; Dzięki temu kontrolki trafią na swoje miejsca (np. z x0 na x500), a AutoSize zmierzy faktyczny układ.
        this.Stan.CzyPokazano := false
        for ctrl in this.Stan.Kontrolki {
            if (ctrl.Type = "Edit" && HasProp(ctrl, "SzerEtykiety") && HasProp(ctrl, "CzyDynamiczne") && ctrl.CzyDynamiczne)
                this.DostosujRozmiar(ctrl.SzerEtykiety, ctrl, ctrl.SzerPola, ctrl.WysInput)
        }
        this.Stan.CzyPokazano := true

        ; [DRY] Użycie wspólnej metody obliczania obszaru
        Content := this.ObliczObszarRoboczy()
        staticW := Content.W
        staticH := Content.H

        ; Oblicz finalne wymiary z uwzględnieniem ramek systemowych
        extraFrame := (this.Stan.UseChild && grubosc > 0) ? (2 * grubosc) : 0

        ; Ekstrakcja wymiarów z Opt (nadpisuje wartości dynamiczne)
        finalW := RegExMatch(Opt, "i)(?:^|\s)w(\d+)", &mW) ? Round(mW[1] * myDpiScale) : (staticW + extraFrame)
        finalH := RegExMatch(Opt, "i)(?:^|\s)h(\d+)", &mH) ? Round(mH[1] * myDpiScale) : (staticH + extraFrame)

        ; [FIX] Zastosowanie kagańca (limitów) na starcie okna
        if (this.Stan.AutoFitW > 0 && !RegExMatch(Opt, "i)(?:^|\s)w(\d+)")) {
            LimitW := (this.Stan.AutoFitW <= 1) ? (A_ScreenWidth * this.Stan.AutoFitW) : Round(this.Stan.AutoFitW * myDpiScale)
            finalW := Round(Min(finalW, LimitW))
        }
        if (this.Stan.AutoFitH > 0 && !RegExMatch(Opt, "i)(?:^|\s)h(\d+)")) {
            LimitH := (this.Stan.AutoFitH <= 1) ? (A_ScreenHeight * this.Stan.AutoFitH) : Round(this.Stan.AutoFitH * myDpiScale)
            finalH := Round(Min(finalH, LimitH))
        }

        ; [FIX] Narzucenie fizycznych kagańców okna przed generacją fazy GDI (Anti-Async Lag)
        if (this.Stan.HasProp("MinW") && this.Stan.MinW > 0)
            finalW := Max(finalW, this.Stan.MinW)
        if (this.Stan.HasProp("MinH") && this.Stan.MinH > 0)
            finalH := Max(finalH, this.Stan.MinH)

        ; Czyszczenie Opt z wymiarów, aby nie dublować parametrów
        Opt := Trim(RegExReplace(Opt, "i)(?:^|\s)[wh]\d+", ""))

        ; [FIX] Usypiamy ramki, by AHK nie dodał ukrytych 30px w AdjustWindowRectEx
        hasResize := (this.Stan.PokazPasek == 0 && (WinGetStyle(this.GuiObj.Hwnd) & 0x40000))
        if (hasResize)
            this.GuiObj.Opt("-Resize")

        ; [STRATEGIA 3] Pre-kalkulacja (Zasada: Wpierw buduj w ukryciu, potem pokazuj)
        this.GuiObj.Show("Hide w" . finalW . " h" . finalH . (Opt ? " " . Opt : ""))


        if (this.Stan.UseChild) {
            ; [FIX] Pochłonięcie AutoSize. Show musi być PRZED layoutem.
            this.Stan.ClipGui.Show("NA")
            this.Stan.ChildGui.Show("NA")

            this.GuiObj.GetClientPos(, , &realW, &realH)
            this.AktualizujLayout(realW, realH, 1) ; Twardy, synchroniczny układ GDI przed renderem
        }

        ; Finalny zrzut na ekran (zero mrugania i glitchy startowych)
        if !InStr(Opt, "Hide")
            this.GuiObj.Show(Opt ? Opt : "")

        this.WymusPelnyRedraw()

        if (this.Stan.UseChild && this.Stan.ChildGui)
            try DllCall("SetFocus", "Ptr", this.Stan.ChildGui.Hwnd)
        if (hasResize)
            this.GuiObj.Opt("+Resize")
    }

    /**
     * Metoda wewnętrzna: Wymusza pełne odświeżenie okna po zakończeniu zmiany rozmiaru.
     * Usuwa artefakty graficzne (ghosting) ramek.
     */
    WymusPelnyRedraw() {
        if (this.GuiObj)
            WinRedraw("ahk_id " . this.GuiObj.Hwnd)
        if (this.Stan.UseChild && this.Stan.ClipGui)
            WinRedraw("ahk_id " . this.Stan.ClipGui.Hwnd)
        if (this.Stan.UseChild && this.Stan.ChildGui)
            WinRedraw("ahk_id " . this.Stan.ChildGui.Hwnd)
        if (this.Stan.UseChild) {
            (this.Stan.VBar) && this.Stan.VBar.Redraw()
            (this.Stan.HBar) && this.Stan.HBar.Redraw()
        }
    }

    /**
     * Oblicza przesunięcie paska tak, aby utrzymać widoczność karetki w trybie PanelTxt.
     * Wywoływana z timerem po zmianie pozycji karetki w kontrolce Edit.
     * @param {Object} ctrl - Kontrolka Edit, której karetka jest monitorowana.
     */
    SledzKaretke(ctrl) {
        if (!this.Stan.UseChild || (!this.Stan.VBar && !this.Stan.HBar))
            return

        try {
            if (ControlGetHwnd(ControlGetFocus("A"), "A") != ctrl.Hwnd)
                return
        } catch
            return

        pt := Buffer(8, 0)
        if !DllCall("GetCaretPos", "Ptr", pt)
            return

        caretX := NumGet(pt, 0, "Int")
        caretY := NumGet(pt, 4, "Int")

        ctrl.GetPos(&cX, &cY), this.Stan.ChildGui.GetPos(&childX, &childY), this.Stan.ClipGui.GetPos(, , &clipW, &clipH)
        absX := cX + caretX + childX
        absY := cY + caretY + childY

        hWiersza := HasProp(ctrl, "WysWiersza") ? ctrl.WysWiersza : 18
        deltaX := (absX < 0) ? (absX - 10) : ((absX + 15 > clipW) ? (absX + 15 - clipW + 10) : 0)
        deltaY := (absY < 0) ? (absY - 4) : ((absY + hWiersza > clipH) ? (absY + hWiersza - clipH + 4) : 0)

        if (deltaX != 0 || deltaY != 0) {
            bar := this.Stan.VBar ? this.Stan.VBar : this.Stan.HBar
            (bar) && bar.PrzewinObszar((this.Stan.HBar ? -deltaX : 0), (this.Stan.VBar ? -deltaY : 0))
        }
    }

    ; Metoda wewnętrzna: Sprząta po zamknięciu okna.
    Zakoncz() {
        ; Usunięcie z rejestru na starcie zabezpiecza przed pętlą rekurencyjną
        for i, inst in SilnikGUI.Statics.AktywneInstancje {
            if (inst == this) {
                SilnikGUI.Statics.AktywneInstancje.RemoveAt(i)
                break
            }
        }

        ; Kaskadowe zamykanie innych instancji, jeśli to główne GUI
        isMain := this.Stan.MainGUI
        if (isMain) {
            AktywneKopia := []
            for inst in SilnikGUI.Statics.AktywneInstancje
                AktywneKopia.Push(inst)
            for inst in AktywneKopia
                try inst.Zakoncz()
        }

        if (SilnikGUI.Statics.StanMButtonScroll.Instancja == this && SilnikGUI.Statics.StanMButtonScroll.Aktywny)
            SilnikGUI.ZakonczMButtonScroll()

        if (HasProp(this.Stan, "DebounceRedraw"))
            SetTimer(this.Stan.DebounceRedraw, 0)

        for dziecko in this.Stan.Dzieci
            try dziecko.Zakoncz()
        this.Stan.Dzieci := []

        ; Sprzątanie handlera przeciągania
        if (this.Stan.HandlerDrag) {
            OnMessage(0x0201, this.Stan.HandlerDrag, 0)
            OnMessage(0x0203, this.Stan.HandlerDrag, 0)
            this.Stan.HandlerDrag := 0
        }
        if (this.GuiObj) {
            try this.GuiObj.DeleteProp("Silnik") ; Rozbicie cyklicznych referencji (Memory Leak fix)
            this.GuiObj.Destroy()
            this.GuiObj := 0
            if (this.Stan.UseChild) {
                try this.Stan.ClipGui.DeleteProp("Silnik")
                try this.Stan.ChildGui.DeleteProp("Silnik")
                if (this.Stan.VBar)
                    try this.Stan.VBar.BarGui.DeleteProp("Silnik")
                if (this.Stan.HBar)
                    try this.Stan.HBar.BarGui.DeleteProp("Silnik")
                this.Stan.ClipGui := 0
                this.Stan.ChildGui := 0
                this.Stan.VBar := 0
                this.Stan.HBar := 0
                this.Stan.Corner := 0
            }
            this.Stan.PopupHwnd := 0
        }

        ; Finalizacja skryptu klienckiego
        if (isMain) {
            if HasMethod(isMain)
                isMain()
            else
                ExitApp()
        }
    }

    /**
     * Główna metoda monitorująca stan interakcji i aktualizująca wygląd GUI.
     * Wywoływana z głównej pętli stanu (GłównaPętlaStanu) dla każdej aktywnej instancji SilnikGUI.
     * @param {Integer} mx - Aktualna pozycja myszy X.
     * @param {Integer} my - Aktualna pozycja myszy Y.
     * @param {Integer} win - Uchwyt okna.
     * @param {Integer} hitHwnd - Uchwyt kontrolki.
     * @param {Integer} foc - Uchwyt kontrolki z fokusem.
     * @param {Integer} IsLBtn - Czy lewy przycisk myszy jest wciśnięty.
     */
    MonitorujStan(mx, my, win, hitHwnd, foc, IsLBtn) {
        if (!this.Stan.RootHwnd)
            this.Stan.RootHwnd := DllCall("GetAncestor", "Ptr", this.GuiObj.Hwnd, "UInt", 2, "Ptr")
        st := this.Stan.MonState

        if !this.GuiObj
            return
        IsActive := WinActive(this.Stan.RootHwnd)

        ; 2. Check Flash (Animacja trwa?)
        CheckFlash(h) => (h && (c := GuiCtrlFromHwnd(h)) && HasProp(c, "FlashEndTime") && A_TickCount < c.FlashEndTime)
        CurrentlyFlashing := (CheckFlash(st.LastFocus) || CheckFlash(st.LastHover))
        IsFlashing := (st.WasFlashing || CurrentlyFlashing) ; [FIX] Przetwarzaj jeśli trwa LUB właśnie się skończyło

        ; 3. IDLE CHECK (Najważniejsza optymalizacja)
        ; Jeśli nic się nie zmieniło i nie ma animacji -> RETURN
        if (!IsFlashing && mx == st.LastInput.x && my == st.LastInput.y && win == st.LastInput.win && hitHwnd == st.LastInput.ctl && foc == st.LastInput.foc && IsActive == st.LastInput.act && IsLBtn == st.LastInput.lbtn)
            return

        ; Aktualizacja snapshotu
        st.LastInput.x := mx, st.LastInput.y := my, st.LastInput.win := win, st.LastInput.ctl := hitHwnd, st.LastInput.foc := foc, st.LastInput.act := IsActive, st.LastInput.lbtn := IsLBtn
        st.WasFlashing := CurrentlyFlashing ; [FIX] Zapisz tylko stan faktyczny (przerywa pętlę)

        ; 4. Obsługa zmiany stanu okna (Active/Inactive)
        if (this.Stan.LastActiveState != IsActive) {
            this.Stan.LastActiveState := IsActive
            col := SilnikGUI.Odcien(SilnikGUI.Motyw.Tlo, SilnikGUI.Motyw.FactorRamki * (IsActive ? 1 : -1))
            this.Stan.AktualnyKolorRamki := col

            colBtn := IsActive ? SilnikGUI.Motyw.Przycisk : SilnikGUI.Motyw.Wklesly
            this.Stan.AktualnyKolorPrzycisku := colBtn

            ; Logika koloru tekstu (Globalny vs Custom)
            DajKolorTxt := (ctrl) => (HasProp(ctrl, "KolorBazowy") ? "c" . (IsActive ? ctrl.KolorBazowy : SilnikGUI.Odcien(ctrl.KolorBazowy, -SilnikGUI.Motyw.FactorNieaktywny)) : (IsActive ? SilnikGUI.Motyw.Tekst : ("c" . SilnikGUI.Motyw.Nieaktywny)))

            colTxt := (IsActive ? SilnikGUI.Motyw.Tekst : ("c" . SilnikGUI.Motyw.Nieaktywny))
            this.Stan.AktualnyKolorTekstu := colTxt

            this.GuiObj.BackColor := col ; [FIX] Aktualizacja tła (Ramki w trybie GDI)
            if (!this.Stan.UseChild)
                WinRedraw(this.GuiObj.Hwnd) ; Wymuś odświeżenie tła pod GDI

            ; [FIX] Iteracja po kontrolkach (Child lub Parent w trybie płaskim)
            TargetObj := this.Stan.UseChild ? this.Stan.ChildGui : this.GuiObj

            if (IsObject(TargetObj)) {
                for c in TargetObj {
                    ; Ignoruj elementy techniczne (Dummy)
                    if HasProp(c, "IsDummy")
                        continue

                    if HasProp(c, "IsFrame") {
                        if (!HasProp(c, "FixedColor") || !c.FixedColor)
                            c.Opt("Background" . col . " Redraw")
                        else
                            c.Opt("Redraw")

                        DllCall("SetWindowPos", "Ptr", c.Hwnd, "Ptr", 1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
                    } else if (HasProp(c, "Rola") && c.Rola == "CustomButton") {
                        c.Opt("Background" . colBtn . " " . colTxt . " Redraw")
                    } else if (c.Type = "Text" || c.Type = "Edit") {
                        c.Opt(DajKolorTxt(c) . " Redraw")
                    }
                }
            }

            ; [MOD] Aktualizacja pasków przewijania (są na Parent, nie Child)
            if (this.Stan.UseChild) {
                UpdateBar := (bar) => (bar && bar.IsVisible && (
                    bar.Btn1.Opt("Background" . SilnikGUI.Motyw.Tlo . " " . colTxt . " Redraw"),
                    bar.Btn2.Opt("Background" . SilnikGUI.Motyw.Tlo . " " . colTxt . " Redraw"),
                    bar.Thumb.Opt("Background" . colBtn . " Redraw")
                ))
                UpdateBar(this.Stan.VBar)
                UpdateBar(this.Stan.HBar)
            }
        }

        ; 5. Logika Hover / Focus
        AktualnyFocusHwnd := (IsActive && foc) ? ControlGetHwnd(foc) : 0
        RealFocusHwnd := IsActive ? (foc ? ControlGetHwnd(foc) : 0) : st.LastRealFocus ; Pamięć natywnego fokusu
        AktualnyHoverHwnd := hitHwnd
        isPopup := (this.Stan.PopupHwnd && win == this.Stan.PopupHwnd)

        ; [MOD] Sticky Hover: Utrzymaj podświetlenie paska przy wciśniętym klawiszu
        if (this.Stan.ActiveScrollLoopCtrl) {
            AktualnyHoverHwnd := this.Stan.ActiveScrollLoopCtrl.Hwnd
        } else if (GetKeyState("LButton", "P") && st.LastHover) {
            ctrl := GuiCtrlFromHwnd(st.LastHover)
            if (ctrl && HasProp(ctrl, "IsScrollbar")) {
                AktualnyHoverHwnd := st.LastHover
            }
        }

        ; [STRATEGIA 1] Pre-Kwarantanna (Szybki filtr instancji)
        ValidWin := isPopup || (win == this.Stan.RootHwnd)

        ; Jeśli kursor na tle Childa (brak kontrolki) lub interakcja zablokowana -> Hover = 0
        if (!AktualnyHoverHwnd || !ValidWin || (!isPopup && !SilnikGUI.CzyMoznaInterakcja(this.GuiObj))) {
            AktualnyHoverHwnd := 0
        } else if (this.Stan.UseChild && AktualnyHoverHwnd == this.Stan.ChildGui.Hwnd) {
            AktualnyHoverHwnd := 0 ; Ignoruj tło Childa
        }

        ; Rozwiąż główne kontrolki dla stanu obecnego i poprzedniego
        GetHwnd(h) => (res := SilnikGUI.RozwiazKontrolke(h, "", this), IsObject(res) ? res.Hwnd : res)
        MainFocusHwnd := GetHwnd(AktualnyFocusHwnd)
        MainHoverHwnd := GetHwnd(AktualnyHoverHwnd)
        MainOldFocusHwnd := GetHwnd(st.LastFocus)
        MainOldHoverHwnd := GetHwnd(st.LastHover)
        MainRealFocusHwnd := GetHwnd(RealFocusHwnd)
        MainOldRealFocusHwnd := GetHwnd(st.LastRealFocus)

        ; Wyrównanie kontrolki w obszarze ClipGui przy uzyskaniu fokusu
        if (MainRealFocusHwnd && MainRealFocusHwnd != MainOldRealFocusHwnd) {
            try {
                if (ctrlFocus := GuiCtrlFromHwnd(MainRealFocusHwnd)) && this.Stan.UseChild && (ctrlFocus.Gui == this.Stan.ChildGui) {
                    (this.Stan.HBar) && this.Stan.HBar.TooFocusMove(ctrlFocus)
                    (this.Stan.VBar) && this.Stan.VBar.TooFocusMove(ctrlFocus)
                }
            }
        }

        ; 6. Aplikuj zmiany (Tylko jeśli Hwnd się różnią lub trwa Flash)
        if (!IsFlashing && MainFocusHwnd == MainOldFocusHwnd && MainHoverHwnd == MainOldHoverHwnd && IsLBtn == st.LastRenderLBtn)
            return

        ; Zbiór unikalnych HWND do odświeżenia
        SetHwnd := Map()
        (MainOldFocusHwnd) && SetHwnd[MainOldFocusHwnd] := 1
        (MainOldHoverHwnd) && SetHwnd[MainOldHoverHwnd] := 1
        (MainFocusHwnd) && SetHwnd[MainFocusHwnd] := 1
        (MainHoverHwnd) && SetHwnd[MainHoverHwnd] := 1

        for hwnd, _ in SetHwnd {
            try {
                ctrl := GuiCtrlFromHwnd(hwnd)
                if (!ctrl || !HasProp(ctrl.Gui, "Silnik") || ctrl.Gui.Silnik != this) ; Zabezpieczenie własności (Anti-Spaghetti Race Condition)
                    continue
                if (hwnd == MainHoverHwnd && HasProp(ctrl, "HoverAction"))
                    ctrl.HoverAction()

                stan := 0 ; Normal
                if (hwnd == MainHoverHwnd && IsLBtn && HasProp(ctrl, "IsScrollbar")) ; [MOD] Hold tylko dla paska
                    stan := 3
                else if (hwnd == MainFocusHwnd)
                    stan := (hwnd == MainHoverHwnd) ? 3 : 2 ; Focus+Hover lub Focus
                else if (hwnd == MainHoverHwnd)
                    stan := 1 ; Hover

                ; Override: Jeśli trwa Flash, wymuś stan 0 (brak podświetlenia)
                if (HasProp(ctrl, "FlashEndTime") && A_TickCount < ctrl.FlashEndTime)
                    stan := 0

                SilnikGUI.NadajStyl(ctrl, stan, this.Stan.AktualnyKolorRamki, this.Stan.AktualnyKolorPrzycisku, this.Stan.AktualnyKolorTekstu)
            }
        }

        st.LastFocus := AktualnyFocusHwnd
        st.LastHover := AktualnyHoverHwnd
        st.LastRealFocus := RealFocusHwnd
        st.LastRenderLBtn := IsLBtn
    }

    /**
     * Metoda wewnętrzna: Obsługuje przeciąganie okna w trybie bez paska (dragBezPaska = true).
     * Wywoływana z OnMessage dla WM_LBUTTONDOWN (0x0201) i WM_LBUTTONDBLCLK (0x0203).
     * @param {Integer} wParam - WPARAM z OnMessage, nie używany.
     * @param {Integer} lParam - LPARAM z OnMessage, nie używany.
     * @param {Integer} msg - Komunikat Windows.
     * @param {Integer} hwnd - Uchwyt okna.
     */
    ObslugaPrzeciaganiaBezPaska(wParam, lParam, msg, hwnd) {
        if (!this.GuiObj)
            return
        try { ; Ochrona przed dostępem do zniszczonego Hwnd
            if (hwnd != this.GuiObj.Hwnd && (!this.Stan.UseChild || hwnd != this.Stan.ChildGui.Hwnd))
                return
        } catch
            return

        ; [FIX] Obsługa Double Click (Maksymalizacja/Przywracanie) - PRZED MinMax
        if (msg == 0x0203) {
            PostMessage(0xA3, 2, 0, this.GuiObj.Hwnd) ; WM_NCLBUTTONDBLCLK (HTCAPTION)
            return
        }

        if WinGetMinMax(hwnd)
            return

        hCtrl := SilnikGUI.GetRealHwndUnderMouse()

        ; Check interaktywnych
        if (hCtrl && hCtrl != hwnd) {
            try {
                ctrl := GuiCtrlFromHwnd(hCtrl)
                ; !!! Lista typów blokujących przeciąganie !!!
                if (ctrl.Type = "Edit" || ctrl.Type = "Button" || ctrl.Type = "DropDownList" || ctrl.Type = "Checkbox" || ctrl.Type = "ListBox")
                    return
                ; !!! Ochrona CustomButton W PRZYSZŁOŚCI DODAĆ TU INNE CUSTOMY !!!
                if (HasProp(ctrl, "Rola") && ctrl.Rola == "CustomButton")
                    return
            }
        }

        ; Tło/Pasywne -> Przeciągnij
        ; [MOD] Bezpośrednie wywołanie przeciągania (Instant Drag)
        PostMessage(0xA1, 2, 0, this.GuiObj.Hwnd)
    }

    /**
     * Wrapper GrupaKontrolek.
     * Zarządza pozycją grupy elementów (Lider + Dekoracje) i automatycznie dopasowuje ramkę.
     */
    class GrupaKontrolek {
        __New(CoreControls, ElementyTablica := []) {
            this.DefineProp("CoreControls", { Value: CoreControls })
            this.DefineProp("MainCtrl", { Value: CoreControls[1] }) ; Lider grupy (do Proxy)
            this.DefineProp("Elementy", { Value: ElementyTablica })
        }

        ; Jawne gettery dla kompatybilności z HasProp()
        Hwnd => this.MainCtrl.Hwnd
        Gui => this.MainCtrl.Gui
        AnchorCtrl => HasProp(this.MainCtrl, "Ramka") ? this.MainCtrl.Ramka : this.MainCtrl

        /**
         * Moves the control group.
         * @param {Boolean} [ApplyScale=true] - Applies DPI scaling to options.
         */
        Move(x := "", y := "", w := "", h := "", ApplyScale := true) {
            Skala := (A_ScreenDPI / 96) * SilnikGUI.Statics.TotalScale
            x := (ApplyScale && x !== "") ? Round(x * Skala) : x
            y := (ApplyScale && y !== "") ? Round(y * Skala) : y
            w := (ApplyScale && w !== "") ? Round(w * Skala) : w
            h := (ApplyScale && h !== "") ? Round(h * Skala) : h

            ; 1. Przygotowanie (Offset ramki)
            off := (HasProp(this.MainCtrl, "GruboscRamki") ? this.MainCtrl.GruboscRamki : 0)

            nx := (x != "") ? (x + off) : unset
            ny := (y != "") ? (y + off) : unset

            ; 2. Przesuń Lidera (MainCtrl) - to wyznacza Deltę dla reszty
            this.MainCtrl.GetPos(&oldX, &oldY, &oldW, &oldH)
            this.MainCtrl.Move(nx?, ny?, w == "" ? unset : w, h == "" ? unset : h)
            this.MainCtrl.GetPos(&newX, &newY, &newW, &newH)

            dX := newX - oldX, dY := newY - oldY

            if (dX = 0 && dY = 0)
                return

            ; 3. Aplikuj Deltę do reszty elementów (Dekoracje: Etykiety, Strzałki)
            for item in this.Elementy {
                ; Pomiń Lidera i Ramkę (Ramka jest liczona osobno)
                if (item.Hwnd == this.MainCtrl.Hwnd || (HasProp(this.MainCtrl, "Ramka") && item == this.MainCtrl.Ramka))
                    continue

                ix := 0, iy := 0
                item.GetPos(&ix, &iy)
                item.Move(ix + dX, iy + dY)
            }

            ; 4. Oblicz Union Rect (CoreControls) i dopasuj Ramkę (Snap)
            if (HasProp(this.MainCtrl, "Ramka")) {
                minX := 99999, minY := 99999, maxX := -99999, maxY := -99999
                for coreItem in this.CoreControls {
                    coreItem.GetPos(&cX, &cY, &cW, &cH)
                    minX := Min(minX, cX)
                    minY := Min(minY, cY)
                    maxX := Max(maxX, cX + cW)
                    maxY := Max(maxY, cY + cH)
                }
                if (minX != 99999) {
                    this.MainCtrl.Ramka.Move(minX - off, minY - off, (maxX - minX) + 2 * off, (maxY - minY) + 2 * off)
                }
            }
        }

        Redraw() {
            try DllCall("InvalidateRect", "Ptr", this.MainCtrl.Gui.Hwnd, "Ptr", 0, "Int", 1)
            this.MainCtrl.Opt("+Redraw")
            for item in this.Elementy {
                if (item.Hwnd == this.MainCtrl.Hwnd)
                    continue
                (HasProp(item, "Redraw")) ? item.Redraw() : item.Opt("+Redraw")
            }
        }

        __Get(Name, Params) => this.MainCtrl.%Name%[Params*]
        __Set(Name, Params, Value) => this.MainCtrl.%Name%[Params*] := Value
        __Call(Name, Params) => this.MainCtrl.%Name%(Params*)
    }

    /**
     * Wymusza ciemny motyw DWM dla podanego okna (pasek tytułu + menu).
     * Działa na Windows 10 (build 17763+) oraz Windows 11.
     * @param {Integer} hwnd - Uchwyt okna.
     * @param {Integer} [tryb=0] - Tryb motywu: 0=Auto (System), 1=Ciemny, 2=Jasny.
     */
    static UstawCiemnyMotywDWM(hwnd, tryb := 0) {
        if (VerCompare(A_OSVersion, "10.0.17763") < 0)
            return

        wlaczycCiemny := false

        if (tryb == 1) {
            wlaczycCiemny := true
        } else if (tryb == 2) {
            wlaczycCiemny := false
        } else {
            ; Auto (motyw systemowy)
            try {
                ; 0=Ciemny, 1=Jasny
                wlaczycCiemny := !RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
            } catch {
                wlaczycCiemny := false ; Błąd -> Jasny
            }
        }

        attr := 20 ; DWMWA_USE_IMMERSIVE_DARK_MODE
        if (VerCompare(A_OSVersion, "10.0.18985") < 0) ; starsze buildy Win10 (1903/1909)
            attr := 19

        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", attr, "Int*", wlaczycCiemny, "Int", 4)
    }

    /**
     * Przełącza okno w tryb pełnoekranowy (bez ramek) i z powrotem.
     * Obsługuje ukrywanie okna podczas tranzycji, aby uniknąć migotania (anti-flicker).
     * @param {Gui} guiObj - Obiekt GUI.
     * @param {Func} [callback=0] - Opcjonalna funkcja wywoływana po zmianie stylu, a przed pokazaniem okna.
     */
    static PelnyEkran(guiObj, callback := 0) {
        static StanOkien := Map() ; Cache stylów
        hwnd := guiObj.Hwnd

        ; sprawadzamy stan okna (1=Max)
        stan := WinGetMinMax(hwnd)
        styl := WinGetStyle(hwnd)

        ; 1. Maskownica (Zrzut: Wymiary pulpitu)
        vX := SysGet(76), vY := SysGet(77)
        vW := SysGet(78), vH := SysGet(79)

        ; Wymuszenie pikseli fizycznych (-DPIScale)
        MaskGui := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20 -DPIScale") ; E0x20 = Przenikanie kliknięć
        MaskGui.BackColor := "000000"

        try {
            ; Zrzut ekranu (GetDC(0))
            hDC := DllCall("GetDC", "Ptr", 0, "Ptr")
            hMemDC := DllCall("CreateCompatibleDC", "Ptr", hDC, "Ptr")
            hBM := DllCall("CreateCompatibleBitmap", "Ptr", hDC, "Int", vW, "Int", vH, "Ptr")
            hOld := DllCall("SelectObject", "Ptr", hMemDC, "Ptr", hBM)

            DllCall("BitBlt", "Ptr", hMemDC, "Int", 0, "Int", 0, "Int", vW, "Int", vH, "Ptr", hDC, "Int", vX, "Int", vY, "UInt", 0x40CC0020) ; Kopiowanie

            DllCall("SelectObject", "Ptr", hMemDC, "Ptr", hOld)
            DllCall("DeleteDC", "Ptr", hMemDC)
            DllCall("ReleaseDC", "Ptr", 0, "Ptr", hDC)

            MaskGui.Add("Picture", "x0 y0 w" . vW . " h" . vH, "HBITMAP:" . hBM)
            DllCall("DeleteObject", "Ptr", hBM) ; Zwolnij oryginał
        }

        MaskGui.Show("NA x" . vX . " y" . vY . " w" . vW . " h" . vH)
        Sleep(50)
        ; Ukrycie pod maską (anty-mruganie)
        WinSetTransparent(0, guiObj)

        if (stan == 1) { ; jesli Max -> Przywróć
            guiObj.Restore()
            WinSetStyle("+0x40000", guiObj) ; +WS_THICKFRAME
            if (StanOkien.Has(hwnd) && StanOkien[hwnd].HadCaption)
                WinSetStyle("+0xC00000", guiObj) ; +WS_CAPTION
            else
                WinSetStyle("-0xC00000", guiObj) ; Brak paska (Tryb Zen)
        } else { ; Normal -> Pełny ekran
            StanOkien[hwnd] := { HadCaption: (styl & 0xC00000) }
            WinSetStyle("-0xC00000", guiObj) ; -WS_CAPTION
            WinSetStyle("-0x40000", guiObj)  ; Ukryj ramkę
            guiObj.Maximize()
        }

        if (callback)
            callback()

        WinSetTransparent(255, guiObj)
        SetTimer(() => MaskGui.Destroy(), -5)
    }

    /**
     * Funkcja pomocnicza do obsługi stref zmiany rozmiaru w oknie bezramkowym.
     * Wywoływana z OnMessage dla WM_NCHITTEST (0x0084) w celu określenia, czy kursor znajduje się na krawędzi okna i jaki jest odpowiedni kod hit testu.
     * @param {Integer} targetHwnd - Uchwyt okna docelowego, dla którego ma być obsługiwany hit test.
     * @param {Integer} margines - Grubość strefy krawędzi (w pikselach), która będzie reagować na zmianę rozmiaru.
     * @param {Integer} wParam - WPARAM z OnMessage, nie używany.
     * @param {Integer} lParam - LPARAM z OnMessage, zawiera współrzędne kursora.
     * @param {Integer} msg - Komunikat Windows (oczekiwany 0x0084).
     * @param {Integer} hwnd - Uchwyt okna, dla którego jest wywoływana funkcja.
     */
    static ObslugaHitTest(targetHwnd, margines, wParam, lParam, msg, hwnd) {
        if (hwnd != targetHwnd)
            return

        if WinGetMinMax("ahk_id " hwnd)
            return 1 ; HTCLIENT

        x := lParam & 0xFFFF
        y := (lParam >> 16) & 0xFFFF

        WinGetPos(&wX, &wY, &wW, &wH, "ahk_id " hwnd)

        top := (y >= wY && y < wY + margines)
        bottom := (y >= wY + wH - margines && y < wY + wH)
        left := (x >= wX && x < wX + margines)
        right := (x >= wX + wW - margines && x < wX + wW)

        if (top && left)
            return 13 ; HTTOPLEFT
        if (top && right)
            return 14 ; HTTOPRIGHT
        if (bottom && left)
            return 16 ; HTBOTTOMLEFT
        if (bottom && right)
            return 17 ; HTBOTTOMRIGHT
        if (top)
            return 12 ; HTTOP
        if (bottom)
            return 15 ; HTBOTTOM
        if (left)
            return 10 ; HTLEFT
        if (right)
            return 11 ; HTRIGHT
        return 1 ; HTCLIENT
    }

    /**
     * Główna metoda obliczająca i aktualizująca układ panelu, w tym widoczność i pozycję pasków przewijania.
     * Wywoływana przy zmianie rozmiaru okna, dodawaniu/usuwaniu kontrolek lub innych zdarzeniach wpływających na układ.
     * @param {Integer} w - Szerokość okna.
     * @param {Integer} h - Wysokość okna.
     * @param {Integer} [start=0] - Flaga wskazująca, czy jest to początkowa konfiguracja (true) czy aktualizacja po zmianie rozmiaru (false). Jeśli true, pozycja scrolla zostanie zresetowana do 0.
     */
    AktualizujLayout(w, h, start := 0) {
        g := this.Stan.GruboscRamki
        gap := this.HasProp("IsPanel") ? this.Stan.RamkaPanelu : g

        ; 1. Przestrzeń startowa
        AvailW := w - (2 * g)
        AvailH := h - (2 * g)

        padX := this.Stan.PadR
        padY := this.Stan.PadD

        ; 2. Treść
        Content := this.ObliczObszarRoboczy()
        ContentW := Content.W ;+ padX
        ContentH := Content.H ;+ padY

        ; 3. Decyzja (Iteracyjna)
        ShowV := false, ShowH := false
        BarSize := this.Stan.VBar ? this.Stan.VBar.BarSize : (this.Stan.HBar ? this.Stan.HBar.BarSize : 20)

        ; A: Pion
        if this.Stan.CSBarV && (ContentH > AvailH) {
            ShowV := true
            AvailW -= (BarSize + gap)
        }

        ; B: Poziom
        if this.Stan.CSBarH && (ContentW > AvailW) {
            ShowH := true
            AvailH -= (BarSize + gap)

            ; [STRATEGIA 2] Adaptacyjny Shrink: Kompresja elastycznych kontrolek przed VBar
            if (ContentH > AvailH) {
                for c in this.Stan.Kontrolki {
                    if (HasProp(c, "FlexH") && c.FlexH) {
                        c.GetPos(&cX, &cY, &cW, &cH)
                        realH := SendMessage(0x00BA, 0, 0, c.Hwnd) * (HasProp(c, "WysWiersza") ? c.WysWiersza : 18)

                        if (cY + cH + padY > AvailH) {
                            noweH := AvailH - cY - padY
                            if (noweH >= realH) {
                                c.Move(, , , noweH)
                                this.Stan.LastObszarTick := 0
                                ContentH := this.ObliczObszarRoboczy().H
                            }
                        }
                    }
                }
            }
        }

        ; C: Korekta zwrotna
        if this.Stan.CSBarV && (!ShowV && ContentH > AvailH) {
            ShowV := true
            AvailW -= (BarSize + gap)
        }

        ; [FIX] Twarda blokada VBar: Pasek odblokuje się tylko, gdy ilość wierszy faktycznie przerośnie ClipGui
        if (ShowV) {
            for c in this.Stan.Kontrolki {
                if (HasProp(c, "FlexH") && c.FlexH) {
                    realH := SendMessage(0x00BA, 0, 0, c.Hwnd) * (HasProp(c, "WysWiersza") ? c.WysWiersza : 18)
                    if (realH <= AvailH) {
                        ShowV := false
                        AvailW += (BarSize + gap) ; Zwrot przestrzeni zabranej przez niedoszły VBar
                        break
                    }
                }
            }
        }

        ; 4. Aplikacja Wymiarów (Atomowe GDI - DeferWindowPos)
        DWP := { Ptr: DllCall("BeginDeferWindowPos", "Int", 12, "Ptr") }
        DeferMove := (ctrl, dx, dy, dw, dh) => (DWP.Ptr ? (DWP.Ptr := DllCall("DeferWindowPos", "Ptr", DWP.Ptr, "Ptr", ctrl.Hwnd, "Ptr", 0, "Int", dx, "Int", dy, "Int", dw, "Int", dh, "UInt", 0x0014, "Ptr")) : ctrl.Move(dx, dy, dw, dh))

        DeferMove(this.Stan.ClipGui, g, g, AvailW, AvailH)

        ; [FIX] Zachowaj pozycję scrolla przy zmianie rozmiaru (Clamp do nowych wymiarów)
        this.Stan.ChildGui.GetPos(&cX, &cY)

        ; Oblicz nową pozycję: Nie pozwól wyjechać poza zakres (0 .. -MaxScroll)
        nX := (start || !ShowH) ? 0 : Min(0, Max(-(ContentW - AvailW), cX))
        nY := (start || !ShowV) ? 0 : Min(0, Max(-(ContentH - AvailH), cY))

        ; 5. Rysowanie Pasków (Faza Atomowa DWP)
        if (ShowV && this.Stan.VBar) {
            this.Stan.VBar.Dopasuj(g + AvailW + gap, g, BarSize, AvailH, ContentH, AvailH, nY, DWP)
        } else if (this.Stan.VBar) {
            this.Stan.VBar.Ukryj()
        }

        if (ShowH && this.Stan.HBar) {
            this.Stan.HBar.Dopasuj(g, g + AvailH + gap, AvailW, BarSize, ContentW, AvailW, nX, DWP)
        } else if (this.Stan.HBar) {
            this.Stan.HBar.Ukryj()
        }

        ; 6. Zaślepka
        if (ShowV && ShowH) {
            DeferMove(this.Stan.Corner, g + AvailW + gap, g + AvailH + gap, BarSize, BarSize)
            if !this.Stan.Corner.Visible
                this.Stan.Corner.Visible := true
        } else {
            if this.Stan.Corner.Visible
                this.Stan.Corner.Visible := false
        }

        ; [TAGOWANIE WinAPI] Oznacz ClipGui dla bezkontaktowego #HotIf (Zero AHK Objects)
        if (ShowV || ShowH)
            Utils.SetTag(this.Stan.ClipGui.Hwnd, "SilnikScrollablePtr", ObjPtr(this))
        else
            Utils.RemoveTag(this.Stan.ClipGui.Hwnd, "SilnikScrollablePtr")

        ; Zrzut ekranowy (Koniec transakcji atomowej DWP)
        if (DWP.Ptr)
            DllCall("EndDeferWindowPos", "Ptr", DWP.Ptr)

        ; --- FAZA SYNCHRONICZNA (Po zrzucie na ekran) ---
        ; Przesunięcia dzieci i ciężkich kontenerów bez niszczenia optymalizacji GPU
        this.Stan.ChildGui.Move(nX, nY, Max(AvailW, ContentW), Max(AvailH, ContentH))

        if (ShowV && this.Stan.VBar)
            this.Stan.VBar.RenderujWnetrze(nY)
        if (ShowH && this.Stan.HBar)
            this.Stan.HBar.RenderujWnetrze(nX)

        ; 7. Callback
        if (this.CallbackLayout)
            this.CallbackLayout.Call(AvailW, 0)
    }

    /**
     * [ETAP 2] Klasa Paska Przewijania (Kompozyt 4 kontrolek).
     */
    class PasekPrzewijania {
        static StanMod := { PokazanyTip: 0, timeAlt: 0, timeCtrl: 0, lastAlt: 0, lastCtrl: 0, czasScrolla: 0, TimerObj: 0, lastAlpha: 0.0 }

        ; Obserwator klawiszy Alt/Ctrl bez alokacji domknięć (Closure).
        static MonitorujModyfikatory() {
            s := SilnikGUI.PasekPrzewijania.StanMod
            GetAlt := GetKeyState("Alt", "P"), GetCtrl := GetKeyState("Ctrl", "P")
            if (GetAlt && !s.lastAlt)
                s.timeAlt := A_TickCount
            if (GetCtrl && !s.lastCtrl)
                s.timeCtrl := A_TickCount
            s.lastAlt := GetAlt, s.lastCtrl := GetCtrl
            if (!GetAlt && !GetCtrl) {
                if (s.PokazanyTip && (A_TickCount - s.czasScrolla < 1000))
                    SilnikGUI.CustomTooltip("Speed x 1", { opoznienie: 0, czas: 1000, Transparent: s.lastAlpha })
                s.PokazanyTip := 0, SetTimer(s.TimerObj, 0)
            }
        }

        /**
         * Pomocnik wykonujący akcję scrolla na konkretnym silniku.
         * Rozwiązuje konflikt scrolla głównego z natywnymi paskami przewijania kontrolek.
         * @param {SilnikGUI} Silnik - Referencja do instancji silnika.
         * @param {Integer} kierunek - Kierunek scrollowania (1 lub -1).
         * @param {Boolean} isHoriz - Flaga osi poziomej.
         * @param {Object} [opcje] - Opcjonalny obiekt konfiguracyjny z parametrami:
         * - [trybMyszy: Boolean] {Boolean} Ograniczenie scrolla do aktualnej pozycji kursora (domyślnie false).
         * - [cX: 0] {Integer} Względna pozycja X kursora na Canvasie.
         * - [cY: 0] {Integer} Względna pozycja Y kursora na Canvasie.
         * - [chronKontrolki: false] {Boolean} Ignorowanie kontrolek pod kursorem na poczet scrollowania głównego.
         * - [ctrlPobrano: false] {Boolean} Bufor detekcji - czy kursor był już sprawdzany w tej klatce.
         * - [ctrlUnderMouse: null] {GuiCtrl} Znaleziona kontrolka pod kursorem do scrollowania punktowego.
         * - [Vstep: 50] {Integer} Krok pionowy (domyślnie 50).
         * - [Hstep: 50] {Integer} Krok poziomy (domyślnie 50).
         * @returns {Boolean} - Zwraca True jeśli scroll został wykonany.
         */
        static _WykonajScrollNaSilniku(Silnik, kierunek, isHoriz, opcje?) {
            opcje := Utils.MergeOptions(opcje?, { trybMyszy: false, cX: 0, cY: 0, chronKontrolki: false, Vstep: 50, Hstep: 50 })
            trybMyszy := opcje.trybMyszy, cX := opcje.cX, cY := opcje.cY, chronKontrolki := opcje.chronKontrolki, Vstep := opcje.Vstep, Hstep := opcje.Hstep

            if (!Silnik.Stan.UseChild)
                return false

            docelowyPasek := isHoriz ? Silnik.Stan.HBar : Silnik.Stan.VBar

            if (trybMyszy) {
                inVBar := (bar := Silnik.Stan.VBar) && bar.IsVisible && cX >= bar.LastGeo.x && cX <= bar.LastGeo.x + bar.LastGeo.w && cY >= bar.LastGeo.y && cY <= bar.LastGeo.y + bar.LastGeo.h
                inHBar := (bar := Silnik.Stan.HBar) && bar.IsVisible && cX >= bar.LastGeo.x && cX <= bar.LastGeo.x + bar.LastGeo.w && cY >= bar.LastGeo.y && cY <= bar.LastGeo.y + bar.LastGeo.h
                Silnik.Stan.ClipGui.GetPos(&vX, &vY, &vW, &vH)
                inClip := (cX >= vX && cX <= vX + vW && cY >= vY && cY <= vY + vH)

                if (!inVBar && !inHBar && !inClip)
                    return false

                if (inVBar)
                    return (Silnik.Stan.VBar.AkcjaRolki(kierunek, Vstep), true)
                if (inHBar)
                    return (Silnik.Stan.HBar.AkcjaRolki(kierunek, Hstep), true)

                if (!chronKontrolki) {
                    if (!opcje.HasProp("ctrlPobrano") || !opcje.ctrlPobrano) {
                        opcje.ctrlUnderMouse := SilnikGUI.ObslugaInterakcji(0, 0, 0, 0, true)
                        opcje.ctrlPobrano := true
                    }
                    if (opcje.HasProp("ctrlUnderMouse") && opcje.ctrlUnderMouse && SilnikGUI._WykonajScrollNaKontrolce(opcje.ctrlUnderMouse, kierunek, isHoriz))
                        return true
                }
            }

            if (docelowyPasek && docelowyPasek.IsVisible) {
                SilnikGUI.Statics.OstatniScrollTick := A_TickCount
                return (docelowyPasek.AkcjaRolki(kierunek, isHoriz ? Hstep : Vstep), true)
            }
            return false
        }


        /**
         * Sprawdza, czy kursor myszy znajduje się nad silnikiem posiadającym aktywne paski przewijania.
         * Weryfikuje warunki brzegowe pozwalające na uruchomienie autoscrolla.
         * @param {Boolean} [ZwracajInstancje=false] - Czy funkcja ma zwrócić znalezioną instancję silnika przez referencję.
         * @param {VarRef} [Instancja] - Referencja wyjściowa do obiektu SilnikGUI (jeśli ZwracajInstancje to true).
         * @returns {Boolean} - True, jeśli autoscroll może zostać uruchomiony.
         */
        static CzyGotowyNaMButtonScroll(ZwracajInstancje := false, &Instancja?) {
            if SilnikGUI.Statics.StanMButtonScroll.Aktywny
                return true

            ; [CZYSTE WinAPI] Szukanie tagu "SilnikScrollablePtr" (Override 16-bit)
            hCtrl := SilnikGUI.GetRealHwndUnderMouse()

            curr := hCtrl
            while (curr) {
                if (ptr := Utils.GetTag(curr, "SilnikScrollablePtr")) {
                    if (ZwracajInstancje)
                        Instancja := ObjFromPtrAddRef(ptr)
                    return true
                }
                curr := DllCall("GetAncestor", "Ptr", curr, "UInt", 1, "Ptr") ; GA_PARENT
            }
            return false
        }

        /**
         * Inicjuje system globalnego autoscrollowania (MButtonScroll) dla danego silnika.
         * Aktywuje tarczę systemową, podmienia kursor graficzny i uruchamia asynchroniczną pętlę przesunięć.
         * @param {SilnikGUI} Silnik - Referencja do docelowego silnika GUI.
         * @param {Object} [Opcje] - Opcjonalny obiekt konfiguracyjny z parametrami:
         * - [czulosc = 0.05] {Float} - Mnożnik czułości wektora prędkości.
         * - [deadzone = 15] {Integer} - Promień (px) strefy martwej wokół punktu startu, w której scroll pauzuje.
         * - [progHamowania = 200] {Integer} - Baza dystansu (px) od ściany, od którego zaczyna się predykcyjne tłumienie.
         * - [czasToggle = 200] {Integer} - Max czas (ms) od kliknięcia do puszczenia, aby przejść w tryb bez trzymania.
         * - [wybieg = 1] {Float} - Współczynnik pędu resztkowego oddawanego do silnika kinetycznego po zakończeniu.
         * - [progFaktor = 8] {Integer} - Mnożnik skalowania strefy hamowania dla krótkich list (Dynamic Damping).
         */
        static UruchomMButtonScroll(Silnik, Opcje?) {
            Opcje := Utils.MergeOptions(Opcje?, { MBCurScale: SilnikGUI.ConfigScroll.MBCurScale, MBuCz: SilnikGUI.ConfigScroll.MBuCz, MBuDeadZone: SilnikGUI.ConfigScroll.MBuDeadZone, MBuProgHam: SilnikGUI.ConfigScroll.MBuProgHam, MBuProgFakt: SilnikGUI.ConfigScroll.MBuProgFakt, MBuWyb: SilnikGUI.ConfigScroll.MBuWyb, MBuToggleT: SilnikGUI.ConfigScroll.MBuToggleT, MBuMaxSpeed: SilnikGUI.ConfigScroll.MBuMaxSpeed })

            DllCall("GetCursorPos", "Ptr", pt := Buffer(8))
            sx := NumGet(pt, 0, "Int"), sy := NumGet(pt, 4, "Int")

            st := SilnikGUI.Statics.StanMButtonScroll
            st.Aktywny := true, st.TrybToggle := false, st.Instancja := Silnik
            st.StartX := sx, st.StartY := sy, st.TickStart := A_TickCount
            st.OstatnieVx := 0, st.OstatnieVy := 0
            st.AccumX := 0.0, st.AccumY := 0.0
            st.CanX := (Silnik.Stan.HBar && Silnik.Stan.HBar.IsVisible)
            st.CanY := (Silnik.Stan.VBar && Silnik.Stan.VBar.IsVisible)
            st.Opcje := Opcje

            st.LastCurId := (st.CanX && !st.CanY) ? 32644 : ((st.CanY && !st.CanX) ? 32645 : 32646)
            st.LastClipDir := ""
            st.LastScale := 1.0
            hCursor := DllCall("LoadCursor", "Ptr", 0, "UInt", st.LastCurId, "Ptr")
            if (st.Fake)
                st.Fake.Destroy()
            st.Fake := SilnikGUI.FakeCur(Silnik.GuiObj.Hwnd, hCursor, "", 1.0)
            st.Fake.Move(sx, sy)

            DllCall("SetCursor", "Ptr", 0)
            DllCall("SetCapture", "Ptr", Silnik.GuiObj.Hwnd)

            SilnikGUI.AktualizujHooka()

            if !SilnikGUI.Statics.ZakonczMButtonScrollObj
                SilnikGUI.Statics.ZakonczMButtonScrollObj := ObjBindMethod(SilnikGUI, "ZakonczMButtonScroll")
            if !SilnikGUI.Statics.PetlaMButtonScrollObj
                SilnikGUI.Statics.PetlaMButtonScrollObj := ObjBindMethod(SilnikGUI, "PetlaMButtonScroll")

            SetTimer(SilnikGUI.Statics.PetlaMButtonScrollObj, SilnikGUI.TickRate)
        }
        /**
         * Inicjuje nową instancję paska przewijania.
         * @param {SilnikGUI} Silnik - Referencja do docelowego silnika GUI.
         * @param {String} Typ - Typ paska ("V" dla pionowego, "H" dla poziomego).
         * @tag WinAPI: "IsSilnikScrollbarBtn" (przyciski), "IsSilnikScrollbarThumb" (suwak), "IsSilnikScrollbarTrack" (tło).
         */
        __New(Silnik, Typ) {
            skala := SilnikGUI.Statics.TotalScale
            this.Silnik := Silnik
            this.Typ := Typ ; "V" lub "H"
            this.BarSize := Round(SilnikGUI.ConfigScroll.BarSize * skala) ; Skalowana szerokość
            this.LastGeo := { x: 0, y: 0, w: 0, h: 0, Content: 0, View: 0, TrackLen: 0, BS: 0 } ; Cache geometrii
            this.IsVisible := false ; Flaga widoczności kontenera

            ; [ASYNC SCROLL] Ujednolicony silnik kinetyczny
            this.Kinetyka := { Cel: 0.0, Curr: 0.0, Vis: 0, Timer: ObjBindMethod(this, "SilnikKinetyczny"), Aktywny: false, TrybFocus: false }

            ; [STATE MACHINE] Globalny stan interakcji (Zastępuje dziesiątki pętli)
            this.BoundPetla := ObjBindMethod(this, "GlownaPetlaPaska")
            this.StanInt := { Tryb: "Brak" }

            ; [STRATEGIA 3] Tworzenie niezależnego pod-okna dla paska (Sub-Container)
            this.BarGui := Gui("-Caption -Border +Parent" . Silnik.GuiObj.Hwnd . " +0x02000000 -DPIScale")
            this.BarGui.BackColor := SilnikGUI.Motyw.Tlo
            this.BarGui.Silnik := Silnik ; Przekazanie referencji (pozwala podświetlać ramkę przy Hover)
            GuiObj := this.BarGui

            ; Symbole strzałek (Segoe UI Symbol dla symetrii)
            Sym1 := (Typ = "V") ? "▲" : "◄"
            Sym2 := (Typ = "V") ? "▼" : "►"

            ; Styl przycisków (CustomButton)
            OptBtn := "+0x200 Center Background" . SilnikGUI.Motyw.Tlo . " " . SilnikGUI.Motyw.Tekst . " +0x100"

            this.Btn1 := GuiObj.Add("Text", OptBtn, Sym1)
            this.Btn2 := GuiObj.Add("Text", OptBtn, Sym2)
            this.Btn1.SetFont("s" . 9 * skala, "arial")
            this.Btn2.SetFont("s" . 9 * skala, "arial")

            this.Thumb := GuiObj.Add("Text", "+0x100 Background" . SilnikGUI.Motyw.Przycisk)

            ; [MOD] Rejestracja w systemie stylów (Hover) i bariery geometrycznej
            this.Btn1.Rola := "CSBarButton", this.Btn1.IsScrollbar := true
            this.Btn2.Rola := "CSBarButton", this.Btn2.IsScrollbar := true
            this.Thumb.Rola := "CustomButton", this.Thumb.IsScrollbar := true
            this.IsScrollbar := true
            this.Hwnd := this.BarGui.Hwnd
            this.Gui := this.BarGui

            ; [GLOBALNA DETEKCJA] Tagowanie okien dla mouse_ctrl (Cross-Process)
            Utils.SetTag(this.Btn1.Hwnd, "IsSilnikScrollbarBtn")
            Utils.SetTag(this.Btn2.Hwnd, "IsSilnikScrollbarBtn")
            Utils.SetTag(this.Thumb.Hwnd, "IsSilnikScrollbarThumb")
            Utils.SetTag(this.BarGui.Hwnd, "IsSilnikScrollbarTrack")

            this.Btn1.MouseDownAction := ObjBindMethod(this, "ObslugaPrzycisku", 1)
            this.Btn2.MouseDownAction := ObjBindMethod(this, "ObslugaPrzycisku", -1)
            this.Thumb.MouseDownAction := ObjBindMethod(this, "ObslugaSuwaka")
            this.MouseDownAction := ObjBindMethod(this, "ObslugaTla")

            ; [NOWOSC] Obsługa Scrolla (Wheel) dla wszystkich elementów paska
            BoundScroll := ObjBindMethod(this, "AkcjaRolki")

            this.Btn1.ScrollAction := BoundScroll
            this.Btn2.ScrollAction := BoundScroll
            this.Thumb.ScrollAction := BoundScroll

        }
        /**
         * Główna metoda dopasowująca pasek do nowych wymiarów i pozycji.
         * Oblicza geometrię, aktualizuje pozycję i rozmiar kontenera, a następnie renderuje wnętrze (przyciski i suwak) synchronicznie.
         * @param {Integer} x - Pozycja X paska.
         * @param {Integer} y - Pozycja Y paska.
         * @param {Integer} w - Szerokość paska.
         * @param {Integer} h - Wysokość paska.
         * @param {Integer} ContentSize - Całkowity rozmiar treści (do przewijania).
         * @param {Integer} ViewSize - Rozmiar widoku (obszar widoczny).
         * @param {Integer} ScrollPos - Aktualna pozycja scrolla (ujemna, jeśli przewijamy w dół/prawo).
         * @param {Object} [DWP=0] - Opcjonalny obiekt transakcji DeferWindowPos dla atomowego przesunięcia całego paska bez migotania. Jeśli nie podany, przesunięcie będzie natychmiastowe.
         */
        Dopasuj(x, y, w, h, ContentSize, ViewSize, ScrollPos, DWP := 0) {
            bs := this.BarSize
            IsV := (this.Typ = "V")

            ; Cache geometrii dla interakcji
            TrackLen := (IsV ? h : w) - (2 * bs)
            this.LastGeo := { x: x, y: y, w: w, h: h, Content: ContentSize, View: ViewSize, TrackLen: TrackLen, BS: bs }

            if (TrackLen <= 0) { ; Za mało miejsca na pasek
                this.Ukryj()
                return
            }

            ; [FIX] Atomowe przesunięcie całego kontenera paska (na wspólnym parencie)
            if DWP && DWP.Ptr
                DWP.Ptr := DllCall("DeferWindowPos", "Ptr", DWP.Ptr, "Ptr", this.BarGui.Hwnd, "Ptr", 0, "Int", x, "Int", y, "Int", w, "Int", h, "UInt", 0x0014, "Ptr")
            if (!DWP || !DWP.Ptr)
                this.BarGui.Move(x, y, w, h)

            if !this.IsVisible {
                this.BarGui.Show("NA")
                this.IsVisible := true
            }

            ; Renderowanie synchroniczne we własnym cyklu (gdy nie używamy DWP)
            if (!DWP || !DWP.Ptr)
                this.RenderujWnetrze(ScrollPos)
        }
        /**
         * Metoda aktualizująca pozycję i rozmiar przycisków oraz suwaka wewnątrz paska.
         * Wywoływana po każdej zmianie pozycji scrolla lub rozmiaru, aby odświeżyć układ elementów wewnętrznych.
         * @param {Integer} ScrollPos - Aktualna pozycja scrolla (ujemna, jeśli przewijamy w dół/prawo).
         */
        RenderujWnetrze(ScrollPos) {
            if (!this.IsVisible)
                return

            geo := this.LastGeo
            IsV := (this.Typ = "V")
            cW := geo.BS, cH := geo.BS

            ; 1. Wnętrze (Lokalne relatywne wsp.)
            this.Btn1.Move(0, 0, cW, cH)
            this.Btn2.Move(IsV ? 0 : (geo.w - geo.BS), IsV ? (geo.h - geo.BS) : 0, cW, cH)

            this.ZaktualizujSuwak(ScrollPos)
        }
        /**
         * Metoda obliczająca i aktualizująca pozycję oraz rozmiar suwaka (Thumb) na podstawie aktualnej pozycji scrolla, rozmiaru treści i widoku.
         * Zapewnia proporcjonalność suwaka do stosunku widoku do treści oraz ogranicza jego ruch do obszaru tracka.
         * @param {Integer} ScrollPos - Aktualna pozycja scrolla (ujemna, jeśli przewijamy w dół/prawo).
         */
        ZaktualizujSuwak(ScrollPos) {
            if (!this.IsVisible) ; Jeśli pasek ukryty, nie aktualizuj
                return

            geo := this.LastGeo
            IsV := (this.Typ = "V")

            Ratio := geo.View / geo.Content
            ThumbLen := Max(SilnikGUI.ConfigScroll.MinThumbSize, Round(geo.TrackLen * Ratio))
            MaxTrack := geo.TrackLen - ThumbLen
            MaxScroll := geo.Content - geo.View

            ThumbPos := (MaxScroll > 0) ? Round((Abs(ScrollPos) / MaxScroll) * MaxTrack) : 0
            ThumbPos := Min(Max(0, ThumbPos), MaxTrack)

            ; Współrzędne Tracka (Lokalne dla BarGui)
            tX := IsV ? 0 : geo.BS
            tY := IsV ? geo.BS : 0
            tW := IsV ? geo.BS : geo.TrackLen
            tH := IsV ? geo.TrackLen : geo.BS

            this.Thumb.Move(IsV ? tX : (tX + ThumbPos), IsV ? (tY + ThumbPos) : tY, IsV ? tW : ThumbLen, IsV ? ThumbLen : tH)
        }
        ;Metoda ukrywająca pasek, jeśli jest widoczny. Wywoływana, gdy nie ma potrzeby wyświetlania paska (np. treść mieści się w widoku).
        Ukryj() {
            if this.IsVisible {
                this.BarGui.Hide()
                this.IsVisible := false
            }
        }
        ; Metoda wymuszająca natychmiastowe odświeżenie paska na ekranie. Przydatna po asynchronicznych zmianach pozycji scrolla lub rozmiaru, gdy nie używamy atomowego DWP.
        Redraw() {
            if (this.IsVisible)
                WinRedraw("ahk_id " . this.BarGui.Hwnd)
        }

        ; --- WSPÓLNY SILNIK KINETYCZNY (KONSUMENT) ---
        SilnikKinetyczny() {
            Dest := this.Kinetyka.Cel
            this.Kinetyka.Curr += (Dest - this.Kinetyka.Curr) * SilnikGUI.ConfigScroll.AnimSoft
            MoveStep := Round(this.Kinetyka.Curr) - this.Kinetyka.Vis

            if (MoveStep != 0) {
                IsV := (this.Typ = "V")
                ; Zatrzymanie "ducha kinetycznego" przy kolizji ze ścianą
                if !this.PrzewinObszar(IsV ? 0 : MoveStep, IsV ? MoveStep : 0) {
                    this.ZatrzymajKinetyke()
                    return
                }
                this.Kinetyka.Vis += MoveStep
            }

            if (Abs(Dest - this.Kinetyka.Curr) < 0) { ;WARUNEK  ZAKOŃCZENIA FIZYKI [1] TO ZA DURZO, CZY [0] SPOWODUJE BŁĘDY?
                this.ZatrzymajKinetyke()
            }
        }
        /**
         * Metoda dodająca "ped" do silnika kinetycznego, inicjująca ruch z określoną prędkością i kierunkiem.
         * Używana zarówno dla akcji rolki, jak i przeciągania suwaka, zapewniając spójne zachowanie kinetyczne.
         * @param {Integer} Delta - Wartość dodawanego peda (dodatkowa prędkość), dodatnia lub ujemna w zależności od kierunku.
         * @param {Boolean} [Limit=0] - Limit prędkości,  jsęli 0, brak limitu.
         */
        DodajPed(Delta, Limit := 0) {
            IsV := (this.Typ = "V")
            this.Silnik.Stan.ChildGui.GetPos(&cX, &cY, &cW, &cH)
            this.Silnik.Stan.ClipGui.GetPos(, , &vW, &vH)

            Dist := IsV ? ((Delta > 0) ? (-cY) : (Max(0, cH - vH) + cY)) : ((Delta > 0) ? (-cX) : (Max(0, cW - vW) + cX))
            Pending := (this.Kinetyka.Cel - this.Kinetyka.Vis) + Delta
            if (Limit > 0)
                Pending := Min(Max(Pending, -Limit), Limit) ; Limit "rozciągnięcia" przed over-coastingiem

            SkokAktualny := ((Delta > 0) ? Min(Pending, Dist) : Max(Pending, -Dist)) - (this.Kinetyka.Cel - this.Kinetyka.Vis)
            this.Kinetyka.Cel += SkokAktualny

            if (!this.Kinetyka.Aktywny) {
                this.Kinetyka.Aktywny := true
                SetTimer(this.Kinetyka.Timer, SilnikGUI.TickRate)
            }

            return SkokAktualny
        }

        ; Atomowy reset fizyki
        ZatrzymajKinetyke() {
            if (!this.Kinetyka.Aktywny)
                return
            SetTimer(this.Kinetyka.Timer, 0)
            this.Kinetyka.Cel := 0.0, this.Kinetyka.Curr := 0.0, this.Kinetyka.Vis := 0
            this.Kinetyka.Aktywny := false
            this.Kinetyka.TrybFocus := false
        }
        ; Metoda zamykająca interakcję z paskiem suwaka, resetująca stan i ewentualnie przywracająca kursor do pozycji startowej. Wywoływana po zakończeniu przeciągania suwaka lub innych interakcji.
        ZakonczInterakcjePaska() {
            this.Silnik.Stan.ActiveScrollLoopCtrl := 0
            SilnikGUI.Statics.AktywnaInstancjaSuwaka := 0
            if HasProp(this.Silnik.Stan, "MonState") {
                this.Silnik.Stan.MonState.LastInput.lbtn := -1
            }
        }
        /**
         * Metoda sprawdzająca, czy pozycja scrolla została przesunięta poza dozwolony obszar (np. przy przenoszeniu okna lub zmianie rozmiaru) i korygująca ją, jeśli to konieczne, poprzez dodanie odpowiedniego peda do silnika kinetycznego.
         * @param {Control} ctrl - Kontrolka, dla której sprawdzana jest pozycja.
         */
        TooFocusMove(ctrl) {
            box := Grafika.ObliczBoundingBox(ctrl)
            if (!box.w && !box.h)
                return
            x := box.x, y := box.y, w := box.w, h := box.h

            this.Silnik.Stan.ChildGui.GetPos(&childX, &childY)
            this.Silnik.Stan.ClipGui.GetPos(, , &clipW, &clipH)

            IsV := (this.Typ == "V")
            pos := IsV ? (y + childY) : (x + childX)
            size := IsV ? h : w
            clip := IsV ? clipH : clipW
            pad := IsV ? this.Silnik.Stan.PadD : this.Silnik.Stan.PadR

            if (pos >= pad && (pos + size) <= (clip - pad))
                return

            Delta := 0
            if (size > clip) {
                if (!IsV && HasProp(ctrl, "InfoRight") && ctrl.InfoRight == 0)
                    Delta := (clip - pad) - (pos + size)
                else
                    Delta := pad - pos
            } else {
                TempPad := ((size + 2 * pad) > clip) ? (clip - size) / 2 : pad
                if (pos < TempPad)
                    Delta := TempPad - pos
                else if ((pos + size) > (clip - TempPad))
                    Delta := (clip - TempPad) - (pos + size)
            }

            if (Delta != 0) {
                this.Kinetyka.TrybFocus := true
                this.DodajPed(Delta)
            }
        }

        /**
         * Metoda wykonująca akcję scrolla (przesunięcia) na silniku, z uwzględnieniem modyfikatorów klawiszy Alt i Ctrl dla dynamicznej zmiany prędkości scrollowania. Wyświetla tymczasowe wskazówki o aktualnej prędkości scrolla i zarządza ich czasem wyświetlania.
         * @param {Mode} Mode - Kierunek scrollowania (1 lub -1) lub obiekt zdarzenia scrolla, z którego można wyciągnąć kierunek i modyfikatory.
         * @param {Integer} [Step=50] - Wartość kroku scrollowania.
         * @param {Array} params - Tablica parametrów. Jeśli Mode jest obiektem zdarzenia, params[1] powinno zawierać kierunek scrollowania. Jeśli Mode jest bezpośrednim kierunkiem, params może być pusta.
         */
        AkcjaRolki(Mode?, Step := 50, params*) {
            kierunek := (IsObject(Mode) && params.Length > 0) ? params[1] : Mode

            s := SilnikGUI.PasekPrzewijania.StanMod
            s.czasScrolla := A_TickCount

            if (!s.TimerObj)
                s.TimerObj := ObjBindMethod(SilnikGUI.PasekPrzewijania, "MonitorujModyfikatory")
            SilnikGUI.PasekPrzewijania.MonitorujModyfikatory()

            ActiveMod := (s.lastAlt && s.lastCtrl) ? ((s.timeAlt > s.timeCtrl) ? "Alt" : "Ctrl") : (s.lastAlt ? "Alt" : (s.lastCtrl ? "Ctrl" : ""))

            pAlpha := WinGetTransparent(this.Silnik.GuiObj.Hwnd)
            s.lastAlpha := IsNumber(pAlpha) ? (1.0 - (pAlpha / 255)) : 0.0

            if (ActiveMod == "Alt") {
                n := SilnikGUI.ConfigScroll.AltFact
                Send("{Blind}{vkE8}"), Step *= n
                if (s.PokazanyTip != 1)
                    SilnikGUI.CustomTooltip("Speed x " SilnikGUI.FormatNum(n, 2), { opoznienie: 0, czas: 1000, Transparent: s.lastAlpha }), s.PokazanyTip := 1, SetTimer(s.TimerObj, SilnikGUI.TickRate)
            } else if (ActiveMod == "Ctrl") {
                n := SilnikGUI.ConfigScroll.CtrlFact
                Step *= n
                if (s.PokazanyTip != 2)
                    SilnikGUI.CustomTooltip("Speed x " SilnikGUI.FormatNum(n, 2), { opoznienie: 0, czas: 1000, Transparent: s.lastAlpha }), s.PokazanyTip := 2, SetTimer(s.TimerObj, SilnikGUI.TickRate)
            }
            this.Kinetyka.TrybFocus := false
            this.DodajPed(kierunek * Step)
        }

        /**
         * Zmienia tryb interakcji paska i zarządza cyklem życia timera.
         * @param {String} nowyStan - Nazwa nowego stanu.
         */
        ZmienStan(nowyStan) {
            if (this.StanInt.Tryb == "Suwak" && nowyStan != "Suwak") {
                try {
                    DllCall("SetCursorPos", "Int", Round(this.StanInt.VisualFakeX), "Int", Round(this.StanInt.VisualFakeY))
                    DllCall("ShowCursor", "Int", 1)
                    this.StanInt.Fake.Destroy()
                    SilnikGUI.CustomTooltip()
                }
            }

            ; Odcięcie fizyki w trybach sztywnych i spoczynku
            if (nowyStan == "Suwak")
                this.ZatrzymajKinetyke()

            this.StanInt.Tryb := nowyStan
            if (nowyStan == "Brak") {
                SetTimer(this.BoundPetla, 0)
                this.ZakonczInterakcjePaska()
            } else {
                SetTimer(this.BoundPetla, SilnikGUI.TickRate)
            }
        }
        /**
         * metoda obsługująca kliknięcie przycisku przewijania (strzałki), inicjująca ruch w określonym kierunku z ustaloną prędkością i aktualizująca stan interakcji paska. Ustawia aktywny kontroler przewijania, dodaje ped do silnika kinetycznego i uruchamia główną pętlę paska.
         * @param {Integer} kierunek - Kierunek przewijania (1 lub -1).
         * @param {Control} ctrl - Kontroler przewijania (opcjonalny).
         */
        ObslugaPrzycisku(kierunek, ctrl?, *) {
            this.Silnik.Stan.ActiveScrollLoopCtrl := IsSet(ctrl) ? ctrl : ((kierunek == 1) ? this.Btn1 : this.Btn2)
            SilnikGUI.Statics.AktywnaInstancjaSuwaka := this.Silnik
            IsV := (this.Typ = "V")
            this.StanInt.Kierunek := kierunek
            this.StanInt.Speed := 0.1
            this.Kinetyka.TrybFocus := false
            this.DodajPed(kierunek * (isV ? SilnikGUI.ConfigScroll.stepYBu : SilnikGUI.ConfigScroll.stepXBu))

            this.ZmienStan("Przycisk")
            this.GlownaPetlaPaska()
        }
        /**
         * Metoda sprawdzająca, czy kursor myszy znajduje się nad określonym kontrolerem suwaka (domyślnie Thumb) lub jego przyciskami. Używana do warunkowania interakcji i wyświetlania podpowiedzi tylko wtedy, gdy kursor jest nad elementami paska.
         * @param {Control} [ctrl=0] - Kontroler suwaka (domyślnie Thumb).
         * @param {VarRef} cX - Referencja wyjściowa do współrzędnej X kursora względem kontenera paska.
         * @param {VarRef} cY - Referencja wyjściowa do współrzędnej Y kursora względem kontenera paska.
         * @return {Boolean} - True, jeśli kursor znajduje się nad kontrolerem suwaka, false w przeciwnym razie.
         */
        CzyKursorNaSuwaku(ctrl := 0, &cX := 0, &cY := 0) {
            IsV := (this.Typ = "V")
            Utils.ScreenToClient(0, this.BarGui.Hwnd, &cX, &cY) ; [FIX] Mysz względem kontenera paska

            (ctrl ? ctrl : this.Thumb).GetPos(&tX, &tY, &tW, &tH)
            return (IsV ? cY >= tY && cY <= tY + tH : cX >= tX && cX <= tX + tW)
        }
        /**
         * Metoda sprawdzająca, czy kursor myszy znajduje się nad tłem paska (nie nad suwakami ani przyciskami). Używana do warunkowania interakcji i wyświetlania podpowiedzi tylko wtedy, gdy kursor jest nad tłem paska.
         * @param {VarRef} cX - Referencja wyjściowa do współrzędnej X kursora względem kontenera paska.
         * @param {VarRef} cY - Referencja wyjściowa do współrzędnej Y kursora względem kontenera paska.
         * @return {Boolean} - True, jeśli kursor znajduje się nad tłem paska, false w przeciwnym razie.
         */
        CzyKursorNaTle(&cX := 0, &cY := 0) {
            Utils.ScreenToClient(0, this.BarGui.Hwnd, &cX, &cY)
            this.BarGui.GetClientPos(, , &bW, &bH)
            if (cX >= 0 && cX <= bW && cY >= 0 && cY <= bH) {
                if !this.CzyKursorNaSuwaku(this.Thumb) && !this.CzyKursorNaSuwaku(this.Btn1) && !this.CzyKursorNaSuwaku(this.Btn2)
                    return true
            }
            return false
        }
        ; Metoda obsługująca przeciąganie suwaka (Thumb), inicjująca interakcję z suwakiem, tworząca fałszywy kursor do płynnego śledzenia ruchu myszy i uruchamiająca główną pętlę paska. Ustawia aktywny kontroler przewijania, oblicza proporcje ruchu suwaka do ruchu scrolla i zarządza stanem interakcji.
        ObslugaSuwaka(*) {
            this.Silnik.Stan.ChildGui.GetPos(&cX, &cY)
            this.Silnik.Stan.ActiveScrollLoopCtrl := this.Thumb
            SilnikGUI.Statics.AktywnaInstancjaSuwaka := this.Silnik
            IsV := (this.Typ = "V")

            geo := this.LastGeo
            Ratio := geo.View / geo.Content
            ThumbLen := Max(SilnikGUI.ConfigScroll.MinThumbSize, Round(geo.TrackLen * Ratio))
            TrackRange := geo.TrackLen - ThumbLen
            ScrollRange := geo.Content - geo.View

            if (TrackRange <= 0) {
                this.ZmienStan("Brak")
                return
            }

            Utils.ClientToScreen(0, 0, &sX, &sY)
            ptBG := Buffer(8, 0), DllCall("ClientToScreen", "Ptr", this.BarGui.Hwnd, "Ptr", ptBG) ; Czysty origin (0,0) kontenera
            bgX := NumGet(ptBG, 0, "Int"), bgY := NumGet(ptBG, 4, "Int")
            trrX := bgX + (IsV ? 0 : geo.BS)
            trrY := bgY + (IsV ? geo.BS : 0)
            trrW := IsV ? geo.w : geo.TrackLen
            trrH := IsV ? geo.TrackLen : geo.h
            Utils.ClientToScreen(this.Thumb, this.BarGui.Hwnd, &thScreenX, &thScreenY)

            this.StanInt.OffsetThumbX := sX - thScreenX
            this.StanInt.OffsetThumbY := sY - thScreenY
            this.StanInt.Factor := ScrollRange / TrackRange
            this.StanInt.Factor1f1 := TrackRange / geo.Content

            Fake := SilnikGUI.FakeCur(this.Silnik.GuiObj.Hwnd)
            Fake.Move(sX, sY)
            DllCall("ShowCursor", "Int", 0)

            this.StanInt.Fake := Fake
            this.StanInt.VisualFakeX := sX
            this.StanInt.VisualFakeY := sY
            this.StanInt.VirtualX := cX
            this.StanInt.VirtualY := cY
            this.StanInt.PrecMod := 1.0
            this.StanInt.NormMod := 1.0
            this.StanInt.MaxScrollX := IsV ? 0 : Max(0, geo.Content - geo.View)
            this.StanInt.MaxScrollY := IsV ? Max(0, geo.Content - geo.View) : 0

            this.StanInt.LastInfo := 1
            this.StanInt.LastPrecKeys := false
            this.StanInt.sX := sX
            this.StanInt.sY := sY
            this.StanInt.trrX := trrX
            this.StanInt.trrY := trrY
            this.StanInt.trrW := trrW
            this.StanInt.trrH := trrH
            this.StanInt.ScrollRange := ScrollRange
            this.StanInt.TrackRange := TrackRange

            this.ZmienStan("Suwak")
            this.GlownaPetlaPaska()
        }
        ; Metoda obsługująca kliknięcie na tle paska (nie na suwaku ani przyciskach), inicjująca interakcję z tłem, ustawiająca aktywny kontroler przewijania i uruchamiająca główną pętlę paska. Umożliwia przewijanie poprzez kliknięcie na pustym obszarze paska, z dynamiczną zmianą prędkości przy dłuższym przytrzymaniu.
        ObslugaTla(*) {
            this.Silnik.Stan.ActiveScrollLoopCtrl := this
            SilnikGUI.Statics.AktywnaInstancjaSuwaka := this.Silnik

            this.StanInt.PierwszyKlik := true
            this.StanInt.Speed := 1.0
            this.Kinetyka.TrybFocus := false

            Utils.ScreenToClient(0, this.BarGui.Hwnd, &cXLast, &cYLast) ; [FIX] Względem okna BarGui
            this.StanInt.cXLast := cXLast
            this.StanInt.cYLast := cYLast

            this.ZmienStan("Tlo")
            this.GlownaPetlaPaska()
        }

        ; Główna maszyna stanów paska. Obsługuje przeciąganie i kliknięcia.
        GlownaPetlaPaska() {
            if !GetKeyState("LButton", "P") {
                this.ZmienStan("Brak")
                return
            }

            if GetKeyState("Alt", "P")
                Send("{Blind}{vkE8}")

            IsV := (this.Typ = "V")

            switch this.StanInt.Tryb {
                case "Przycisk":
                    if this.CzyKursorNaTle()
                        return this.ObslugaTla()
                    if this.CzyKursorNaSuwaku(this.Thumb)
                        return this.ObslugaSuwaka()

                    this.DodajPed(this.StanInt.Kierunek * ((isV ? SilnikGUI.ConfigScroll.stepYBu : SilnikGUI.ConfigScroll.stepXBu) * this.StanInt.Speed), SilnikGUI.ConfigScroll.ArMaxSpeed)
                    this.StanInt.Speed *= SilnikGUI.ConfigScroll.AccBu

                case "Tlo":
                    if this.CzyKursorNaSuwaku(this.Btn1)
                        return this.ObslugaPrzycisku(1, this.Btn1)
                    if this.CzyKursorNaSuwaku(this.Btn2)
                        return this.ObslugaPrzycisku(-1, this.Btn2)

                    this.Thumb.GetPos(&thX, &thY, &thW, &thH)
                    Utils.ScreenToClient(0, this.BarGui.Hwnd, &cX, &cY) ; [FIX] Mysz względem kontenera

                    MousePos := IsV ? cY : cX
                    MousePosLast := IsV ? this.StanInt.cYLast : this.StanInt.cXLast
                    ThumbPos := IsV ? thY : thX
                    ThumbSize := IsV ? thH : thW

                    kierunek := (MousePos < ThumbPos) ? 1 : ((MousePos > ThumbPos + ThumbSize) ? -1 : 0)

                    if this.CzyKursorNaSuwaku(this.Thumb) && !(MousePos == MousePosLast)
                        return this.ObslugaSuwaka()

                    DistToMouse := (kierunek == 1) ? (ThumbPos - MousePos) : (MousePos - (ThumbPos + ThumbSize))
                    geo := this.LastGeo
                    TrackRange := Max(1, geo.TrackLen - ThumbSize)
                    ScrollRange := geo.Content - geo.View
                    DistScrollUnits := DistToMouse * (ScrollRange / TrackRange)
                    DostepnyPed := Max(0, DistScrollUnits - Abs(this.Kinetyka.Cel - this.Kinetyka.Vis))

                    if (this.StanInt.PierwszyKlik) {
                        this.Silnik.Stan.ClipGui.GetPos(, , &vW, &vH)
                        this.DodajPed(kierunek * (IsV ? vH : vW))
                        this.StanInt.PierwszyKlik := false
                    } else {
                        if (DostepnyPed > 0) {
                            this.DodajPed(kierunek * Min(SilnikGUI.ConfigScroll.TloMaxSpeed * this.StanInt.Speed, DostepnyPed))
                            this.StanInt.Speed *= SilnikGUI.ConfigScroll.AccTlo
                        } else {
                            this.StanInt.Speed := 1.0
                        }
                    }

                    this.StanInt.cXLast := cX
                    this.StanInt.cYLast := cY

                case "Suwak":
                    PrecKeys := (GetKeyState("Ctrl", "P") || GetKeyState("Shift", "P") || GetKeyState("Alt", "P"))
                    PrecMod := this.StanInt.PrecMod
                    NormMod := this.StanInt.NormMod

                    addMod := PrecKeys ? PrecMod : NormMod
                    add := (addMod < 0.5 ? Max(0.01, addMod * 0.2) : (addMod < 2 ? addMod * 0.1 : addMod * 0.05))

                    if (sDelta := this.Silnik.Stan.ScrollDelta) {
                        if PrecKeys
                            PrecMod := (sDelta > 0) ? PrecMod + add : Max(0.01, PrecMod - add)
                        else
                            NormMod := (sDelta > 0) ? NormMod + add : Max(0.01, NormMod - add)
                        this.Silnik.Stan.ScrollDelta := 0
                    }

                    if GetKeyState("MButton", "P") {
                        PrecMod := PrecKeys ? 1 : PrecMod
                        NormMod := PrecKeys ? NormMod : 1
                    }

                    this.StanInt.PrecMod := PrecMod
                    this.StanInt.NormMod := NormMod

                    Info := PrecKeys ? PrecMod : NormMod
                    if (Info != this.StanInt.LastInfo || PrecKeys != this.StanInt.LastPrecKeys) {
                        pAlpha := WinGetTransparent(this.Silnik.GuiObj.Hwnd)
                        SilnikGUI.CustomTooltip(PrecKeys ? "x" . Format("{:.2f}", Info) . "`n1:1" : "x" . Format("{:.2f}", Info) . "`nprop.", { opoznienie: 0, czas: 1000, trybPozycji: this.StanInt.Fake, Transparent: IsNumber(pAlpha) ? (1.0 - (pAlpha / 255)) : 0.0 })
                    }

                    this.StanInt.LastInfo := Info
                    this.StanInt.LastPrecKeys := PrecKeys

                    Utils.ClientToScreen(0, 0, &mX, &mY)
                    sX := this.StanInt.sX
                    sY := this.StanInt.sY
                    dMouseX := mX - sX
                    dMouseY := mY - sY

                    if (dMouseX != 0 || dMouseY != 0) {
                        DllCall("SetCursorPos", "Int", sX, "Int", sY)
                        this.Silnik.Stan.ChildGui.GetPos(&cX, &cY)

                        Factor := this.StanInt.Factor
                        Factor1f1 := this.StanInt.Factor1f1
                        Precision := PrecKeys ? Factor1f1 * PrecMod : 1.0 * NormMod

                        RawDelta := IsV ? -(dMouseY * Factor * Precision) : -(dMouseX * Factor * Precision)

                        VirtualX := this.StanInt.VirtualX
                        VirtualY := this.StanInt.VirtualY
                        VisualFakeX := this.StanInt.VisualFakeX
                        VisualFakeY := this.StanInt.VisualFakeY

                        if IsV {
                            VirtualY += RawDelta
                            VisualFakeX += dMouseX * Precision
                            ProgressY := -VirtualY / Max(1, this.StanInt.ScrollRange)
                            VisualFakeY := this.StanInt.trrY + (ProgressY * this.StanInt.TrackRange) + this.StanInt.OffsetThumbY

                            InTrack := (VisualFakeY >= this.StanInt.trrY && VisualFakeY <= this.StanInt.trrY + this.StanInt.trrH)
                            IsOvershoot := (VirtualY > 0 || VirtualY < -this.StanInt.MaxScrollY)

                            if (InTrack && IsOvershoot) {
                                VirtualY := Min(0, Max(-this.StanInt.MaxScrollY, VirtualY))
                                ThumbScreenY_at_edge := this.StanInt.trrY + ((-VirtualY / Max(1, this.StanInt.ScrollRange)) * this.StanInt.TrackRange)
                                this.StanInt.OffsetThumbY := VisualFakeY - ThumbScreenY_at_edge
                            }
                            this.PrzewinObszar(0, VirtualY - cY)
                        } else {
                            VirtualX += RawDelta
                            VisualFakeY += dMouseY * Precision
                            ProgressX := -VirtualX / Max(1, this.StanInt.ScrollRange)
                            VisualFakeX := this.StanInt.trrX + (ProgressX * this.StanInt.TrackRange) + this.StanInt.OffsetThumbX

                            InTrack := (VisualFakeX >= this.StanInt.trrX && VisualFakeX <= this.StanInt.trrX + this.StanInt.trrW)
                            IsOvershoot := (VirtualX > 0 || VirtualX < -this.StanInt.MaxScrollX)

                            if (InTrack && IsOvershoot) {
                                VirtualX := Min(0, Max(-this.StanInt.MaxScrollX, VirtualX))
                                ThumbScreenX_at_edge := this.StanInt.trrX + ((-VirtualX / Max(1, this.StanInt.ScrollRange)) * this.StanInt.TrackRange)
                                this.StanInt.OffsetThumbX := VisualFakeX - ThumbScreenX_at_edge
                            }
                            this.PrzewinObszar(VirtualX - cX, 0)
                        }

                        this.StanInt.VirtualX := VirtualX
                        this.StanInt.VirtualY := VirtualY
                        this.StanInt.VisualFakeX := VisualFakeX
                        this.StanInt.VisualFakeY := VisualFakeY

                        this.StanInt.Fake.Move(VisualFakeX, VisualFakeY)
                    }
            }
        }

        /**
         * Przewija obszar roboczy o zadaną wartość (delta).
         * @param {Integer} dx - Przesunięcie w poziomie.
         * @param {Integer} dy - Przesunięcie w pionie.
         */
        PrzewinObszar(dx, dy) {
            if (!this.Silnik.Stan.UseChild)
                return false

            this.Silnik.Stan.ChildGui.GetPos(&cX, &cY, &cW, &cH) ; Obecna pozycja i rozmiar treści
            this.Silnik.Stan.ClipGui.GetPos(, , &vW, &vH)         ; Rozmiar widoku

            maxX := (cW - vW)
            maxY := Max(0, cH - vH)

            nX := Min(0, Max(-maxX, cX + dx))
            nY := Min(0, Max(-maxY, cY + dy))

            if (nX != cX || nY != cY) {
                this.Silnik.Stan.ChildGui.Move(nX, nY)
                (this.Silnik.Stan.VBar) && this.Silnik.Stan.VBar.ZaktualizujSuwak(nY)
                (this.Silnik.Stan.HBar) && this.Silnik.Stan.HBar.ZaktualizujSuwak(nX)

                this.Silnik.PrzesunTooltipy(nX - cX, nY - cY)
                if (this.Kinetyka.TrybFocus)
                    this.Silnik.PrzesunPopupy(nX - cX, nY - cY)
                else
                    this.Silnik.ZamknijPopupy()
                return true
            }
            return false
        }
    }
}