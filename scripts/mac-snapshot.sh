 #!/bin/bash
# 用法: ./mac-snapshot.sh > snapshot.txt
{
  echo "########## hostname ##########"
  scutil --get ComputerName; scutil --get LocalHostName

  echo "########## macOS version ##########"
  sw_vers

  echo "########## arch ##########"
  uname -m

  echo "########## brew formulae ##########"
  brew list --formula -1 | sort

  echo "########## brew casks ##########"
  brew list --cask -1 | sort

  echo "########## brew taps ##########"
  brew tap | sort

  echo "########## mas (App Store apps) ##########"
  mas list | sort

  echo "########## /Applications ##########"
  ls /Applications | sort

  echo "########## PATH ##########"
  echo $PATH | tr ':' '\n'

  echo "########## shells ##########"
  cat /etc/shells
  echo "default shell: $SHELL"

  echo "########## node global ##########"
  command -v npm >/dev/null && npm ls -g --depth=0 2>/dev/null | sort

  echo "########## python ##########"
  command -v python3 && python3 --version
  command -v pip3 >/dev/null && pip3 list --format=freeze 2>/dev/null | sort

  echo "########## dotfiles in $HOME ##########"
  ls -la ~ | grep '^[-l]' | awk '{print $NF}' | sort
}