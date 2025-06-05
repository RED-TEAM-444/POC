#include <windows.h>
#include <iostream>

// Function pointer to original MessageBoxA
using MessageBoxA_t = int (WINAPI *)(HWND, LPCSTR, LPCSTR, UINT);
MessageBoxA_t OriginalMessageBoxA = nullptr;

// Buffer for original bytes
BYTE originalBytes[5] = {0};
BYTE jmpPatch[5] = {0xE9, 0x00, 0x00, 0x00, 0x00}; // JMP instruction
FARPROC targetAddress = nullptr;

// Trampoline buffer to store original instructions + JMP back
BYTE trampoline[10] = {0};

// Hook function
int WINAPI HookedMessageBoxA(HWND hWnd, LPCSTR lpText, LPCSTR lpCaption, UINT uType) {
    // Modify the message text
    lpText = "Hooked! This is a custom message.";
    
    // Call original MessageBoxA via trampoline
    return OriginalMessageBoxA(hWnd, lpText, lpCaption, uType);
}

// Build trampoline to call original function
void BuildTrampoline() {
    // Copy original 5 bytes
    memcpy(trampoline, originalBytes, 5);
    // Add JMP back to original function (after hooked bytes)
    trampoline[5] = 0xE9; // JMP
    DWORD offset = (DWORD)((BYTE*)targetAddress + 5 - (trampoline + 10));
    memcpy(trampoline + 6, &offset, 4);
    
    // Set OriginalMessageBoxA to point to trampoline
    OriginalMessageBoxA = (MessageBoxA_t)trampoline;
}

// Install the hook
bool SetHook() {
    // Get target function address
    HMODULE hModule = LoadLibraryA("user32.dll");
    if (!hModule) {
        std::cerr << "Failed to load user32.dll: " << GetLastError() << std::endl;
        return false;
    }
    targetAddress = GetProcAddress(hModule, "MessageBoxA");
    if (!targetAddress) {
        std::cerr << "Failed to find MessageBoxA: " << GetLastError() << std::endl;
        return false;
    }

    // Save original bytes
    if (!ReadProcessMemory(GetCurrentProcess(), (LPCVOID)targetAddress, originalBytes, 5, nullptr)) {
        std::cerr << "Failed to read original bytes: " << GetLastError() << std::endl;
        return false;
    }

    // Calculate JMP offset (HookedMessageBoxA - targetAddress - 5)
    DWORD offset = (DWORD)((BYTE*)HookedMessageBoxA - (BYTE*)targetAddress - 5);
    memcpy(jmpPatch + 1, &offset, 4);

    // Change memory protection
    DWORD oldProtect;
    if (!VirtualProtect((LPVOID)targetAddress, 5, PAGE_EXECUTE_READWRITE, &oldProtect)) {
        std::cerr << "Failed to change memory protection: " << GetLastError() << std::endl;
        return false;
    }

    // Write JMP patch
    if (!WriteProcessMemory(GetCurrentProcess(), (LPVOID)targetAddress, jmpPatch, 5, nullptr)) {
        std::cerr << "Failed to write JMP patch: " << GetLastError() << std::endl;
        return false;
    }

    // Restore memory protection
    if (!VirtualProtect((LPVOID)targetAddress, 5, oldProtect, &oldProtect)) {
        std::cerr << "Failed to restore memory protection: " << GetLastError() << std::endl;
        return false;
    }

    // Build trampoline for original function
    BuildTrampoline();

    return true;
}

// Remove the hook
bool RemoveHook() {
    // Change memory protection
    DWORD oldProtect;
    if (!VirtualProtect((LPVOID)targetAddress, 5, PAGE_EXECUTE_READWRITE, &oldProtect)) {
        std::cerr << "Failed to change memory protection: " << GetLastError() << std::endl;
        return false;
    }

    // Restore original bytes
    if (!WriteProcessMemory(GetCurrentProcess(), (LPVOID)targetAddress, originalBytes, 5, nullptr)) {
        std::cerr << "Failed to restore original bytes: " << GetLastError() << std::endl;
        return false;
    }

    // Restore memory protection
    if (!VirtualProtect((LPVOID)targetAddress, 5, oldProtect, &oldProtect)) {
        std::cerr << "Failed to restore memory protection: " << GetLastError() << std::endl;
        return false;
    }
    return true;
}

int main() {
    // Test before hooking
    MessageBoxA(nullptr, "Original message", "Test", MB_OK);
    std::cout << "Original MessageBoxA called.\n";

    // Install hook
    if (SetHook()) {
        std::cout << "Hook installed successfully.\n";
    } else {
        std::cerr << "Failed to install hook.\n";
        return 1;
    }

    // Test after hooking
    MessageBoxA(nullptr, "This should be hooked", "Test", MB_OK);
    std::cout << "Hooked MessageBoxA called.\n";

    // Remove hook
    if (RemoveHook()) {
        std::cout << "Hook removed successfully.\n";
    } else {
        std::cerr << "Failed to remove hook.\n";
        return 1;
    }

    // Test after unhooking
    MessageBoxA(nullptr, "Original message again", "Test", MB_OK);
    std::cout << "Original MessageBoxA called after unhooking.\n";

    return 0;
}
