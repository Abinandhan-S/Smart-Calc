# Calculator App Blueprint

## Overview

This document outlines the structure and features of a Flutter calculator application. The app provides standard calculator functionality along with the ability to save, view, and reuse calculation history.

## Features

*   **Standard Calculator:** A user-friendly interface for performing basic arithmetic operations.
*   **Expression and Result Display:** Shows the current expression being entered and the result of the calculation.
*   **Calculation History:**
    *   Automatically saves each calculated expression.
    *   A dedicated history screen lists all saved formulas.
    *   Users can tap on a saved formula to load it back into the calculator.
    *   The entire history can be cleared.
*   **State Management:** Utilizes the `provider` package for efficient state management.
*   **Local Storage:** Employs the `shared_preferences` package to persist the calculation history on the user's device.

## Project Structure

*   `lib/main.dart`: The main entry point of the application, containing the UI for the calculator and history screens, as well as the state management logic.
*   `pubspec.yaml`: Defines the project dependencies, including `flutter`, `provider`, `shared_preferences`, and `math_expressions`.

## Current Plan

The initial version of the calculator app has been implemented. The core features are complete, including the calculator UI, expression evaluation, history saving, and history management.
