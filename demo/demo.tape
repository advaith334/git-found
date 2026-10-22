# Records demo/demo.gif. Run from the repo root: vhs demo/demo.tape
# Uses example accounts: git-found is real, gh and GitHub are stand-ins (see demo/env.sh).

Output demo/demo.gif

Set Shell "bash"
Set FontSize 20
Set Width 1200
Set Height 500
Set Padding 28
Set Theme "Catppuccin Mocha"
Set TypingSpeed 40ms
Env BASH_SILENCE_DEPRECATION_WARNING "1"

Hide
Type "source demo/env.sh && clear" Enter
Sleep 500ms
Show

Type "# gh accounts: alice (active), alice-work. Only alice-work can see acme-corp/api"
Sleep 1s
Enter
Type "git clone https://github.com/acme-corp/api.git"
Sleep 400ms
Enter
Sleep 3.5s

Type "git-credential-found setup"
Sleep 400ms
Enter
Sleep 4s

Type "git-credential-found which acme-corp/api"
Sleep 400ms
Enter
Sleep 3s

Type "git clone https://github.com/acme-corp/api.git"
Sleep 400ms
Enter
Sleep 4s
