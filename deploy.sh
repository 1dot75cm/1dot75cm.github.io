#!/bin/bash
( eval "$(ssh-agent -s)"
  ssh-add ~/.ssh/id_rsa
  cd public
  git init
  git add .
  git commit -m "Travis-CI Deployed to Github Pages"
  git push -f git@github.com:1dot75cm/1dot75cm.github.io HEAD:master
  rm -rf ~/.ssh; pkill ssh-agent || :
)
