# Records demo/demo.gif. Run from the repo root: vhs demo/demo.tape
# Example accounts: git-found is the real script, gh and GitHub are stand-ins (see demo/env.sh).

Output demo/demo.gif

Set Shell "bash"
Set FontFamily "Menlo"
Set FontSize 19
Set LineHeight 1.25
Set Width 1240
Set Height 720
Set Padding 26
Set Margin 22
Set MarginFill "#5b5f73"
Set WindowBar Colorful
Set BorderRadius 10
Set Theme "Catppuccin Mocha"
Set TypingSpeed 45ms
Env BASH_SILENCE_DEPRECATION_WARNING "1"

Hide
Type "source demo/env.sh && clear" Enter
Sleep 500ms
Show

Sleep 600ms
Type "gh auth status"
Sleep 300ms
Enter
Sleep 2.5s

Type "git clone https://github.com/mycompany/backend.git"
Sleep 300ms
Enter
Sleep 3s

Type "git-credential-found setup"
Sleep 300ms
Enter
Sleep 3.5s

Type "git clone https://github.com/mycompany/backend.git"
Sleep 300ms
Enter
Sleep 5s
