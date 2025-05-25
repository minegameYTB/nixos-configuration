{ config, ... }:

{
 ### stylix
 stylix = {
   targets = {
     tmux.enable = false;
     ### Remove warning for qtct
     qt = {
       enable = true;
       platform = "qtct";
     };
   };
 };
}
