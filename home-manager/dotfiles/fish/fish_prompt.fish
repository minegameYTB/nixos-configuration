function fish_prompt
  fishline -s $status SIGSTATUS JOBS VFISH PWD GIT WRITE N ROOT
  echo -n " " ### No newline (just for a space)
end
