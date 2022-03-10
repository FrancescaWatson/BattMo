(let ((files (directory-files-recursively "."
                                          (rx (zero-or-more anychar) ".m")
                                          nil
                                          (lambda (subdir) (if (seq-contains-p (list "MRST" "docs") subdir (lambda (str1 str2) (string-match-p str1 str2))) nil t)))))
  (with-current-buffer (find-file-noselect "temp.txt")
    (erase-buffer)
    (cl-loop for file in files do (insert file "\n"))
    ))
    
(let* ((files (directory-files-recursively "."
                                           (rx (zero-or-more anychar) ".m")
                                           nil
                                           (lambda (subdir) (if (seq-contains-p (list "MRST" "docs" "agmg") subdir (lambda (str1 str2) (string-match-p str1 str2))) nil t))))
       (files (cl-loop for file in files if (not (with-current-buffer (find-file-noselect file)
                                                   (beginning-of-buffer)
                                                   (re-search-forward "opyright" nil t)
                                                   ))
                       collect file)
              ))
  (with-current-buffer (find-file-noselect "temp.txt")
    (erase-buffer)
    (cl-loop for file in files do (insert file "\n"))
    (save-buffer)
    )
  (cl-loop for file in files do (with-current-buffer (find-file-noselect file)
                                  (end-of-buffer)
                                  (insert "\n\n")
                                  (insert copyright-text)
                                  (save-buffer)
                                                   )
           )
  )



(setq copyright-text
"
%{
Copyright 2009-2021 SINTEF Industry, Sustainable Energy Technology
and SINTEF Digital, Mathematics & Cybernetics.

This file is part of The Battery Modeling Toolbox BatMo

BatMo is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

BatMo is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with BatMo.  If not, see <http://www.gnu.org/licenses/>.
%}
"
)


