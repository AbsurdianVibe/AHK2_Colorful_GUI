# SilnikGUI (AHK v2 Custom UI)

This is a custom User Interface (UI) library for AutoHotkey v2. It helps you build modern windows with a dark theme, custom scrollbars, and smooth animations.

## ⚠️ Project Status & History

This project is moving from "manual local backups" to "GitHub is awesome". This is one of my first big projects. I wrote it for myself, but it grew into my biggest project.

**Note:** The code, variables, and comments are in Polish. This is legacy code.

I am moving to other programming languages. I will "freeze" (stop updating) this project soon. Before I freeze it, I will finish these last features:
- Custom context menu.
- Slider control.
- Custom window title bar.
- Code cleanup (refactoring).
- Better configuration strategy for client scripts.

## 📚 Full Manual
A complete manual with all technical details and instructions will be added here in the future.

## Features

- **Any Color Theme:** It automatically calculates colors for borders, buttons, and text.
- **Smooth Scrolling:** Kinetic scrollbars and mouse wheel support.
- **Custom Controls:** It has custom checkboxes, dropdown lists (DDList), buttons, and inputs.
- **Smart Tooltips:** Custom popups that follow the mouse or stick to controls.

## Quick Start

Include the file in your AHK v2 script. Use the `SilnikGUI` class to create a new window.

```ahk
#Requires AutoHotkey v2.0
#Include AHK2ColorfulGUI.ahk

; Create a new window
App := SilnikGUI("My App Title")

; Add a config row (Label + Input field)
App.DodajWierszKonfiguracji("Username:", "DefaultName")

; Add a custom button
App.DodajPrzycisk("Click Me", MyFunction)

; Show the window
App.Pokaz("w400 h300")

MyFunction(ctrl, info) {
    MsgBox("Button clicked!")
}