#
##  Rd2dvi -- Convert man pages (*.Rd help files) via LaTeX to DVI/PDF.
##
## Examples:
##  Rcmd Rd2dvi.sh /path/to/Rsrc/src/library/base/man/Normal.Rd
##  Rcmd Rd2dvi.sh `grep -l "\\keyword{distr" \
##                  /path/to/Rsrc/src/library/base/man/*.Rd | sort | uniq`

R_PAPERSIZE=${R_PAPERSIZE-a4}

revision='$Revision: 1.11 $'
version=`set - ${revision}; echo ${2}`
version="Rd2dvi.sh ${version}

Copyright (C) 2000-2001 The R Core Development Team.
This is free software; see the GNU General Public Licence version 2
or later for copying conditions.  There is NO warranty." 

usage="Usage: R CMD Rd2dvi [options] files

Generate DVI (or PDF) output from the Rd sources specified by files, by
either giving the paths to the files, or the path to a directory with
the sources of a package.

Options:
  -h, --help		print short help message and exit
  -v, --version		print version info and exit  
      --debug		turn on shell debugging (set -x)
      --no-clean	do not remove created temporary files
      --no-preview	do not preview generated output file
      --os=NAME		use OS subdir \`NAME\' (unix, mac or windows)
      --OS=NAME		the same as \`--os\'
  -o, --output=FILE	write output to FILE
      --pdf		generate PDF output
      --title=NAME	use NAME as the title of the document
  -V, --verbose		report on what is done

Report bugs to <r-bugs@r-project.org>."

TEXINPUTS=.:${R_HOME}/doc/manual:${TEXINPUTS}

start_dir=`pwd`

clean=true
debug=false
out_ext="dvi"
output=""
preview=${xdvi-xdvi.bat}
verbose=false
OSdir=windows

${verbose} "Parsing arguments ..."
while test -n "${1}"; do
  case ${1} in
    -h|--help)
      echo "${usage}"; exit 0 ;;
    -v|--version)
      echo "${version}"; exit 0 ;;
    --debug)
      debug=true ;;
    --no-clean)
      clean=false ;;
    --no-preview)
      preview=false ;;
    --pdf)
      out_ext="pdf";
      preview=false;
      R_RD4DVI=${R_RD4PDF-"ae,hyper"};
      R_LATEXCMD=${PDFLATEX-pdflatex};;
    --title=*)
      title=`echo "${1}" | sed -e 's/[^=]*=//'` ;;
    -o)
      if test -n "`echo ${2} | sed 's/^-.*//'`"; then      
	output="${2}"; shift
      else
	echo "ERROR: option \`${1}' requires an argument"
	exit 1
      fi
      ;;
    --output=*)
      output=`echo "${1}" | sed -e 's/[^=]*=//'` ;;
    --OS=*|--os=*)
      OSdir=`echo "${1}" | sed -e 's/[^=]*=//'` ;;
    -V|--verbose)
      verbose=echo ;;
    --|*)
      break ;;
  esac
  shift
done

if test -z "${output}"; then
  output=Rd2.${out_ext}
fi

if ${debug}; then set -x; fi

get_dcf_field () {
  ## Get one field including all continuation lines from a DCF file.
  ws="[         ]"              # space and tab
  sed -n "/^${1}:/,/^[^ ]/{p;}" ${2} | \
    sed -n "/^${1}:/{s/^${1}:${ws}*//;p;}
            /^${ws}/{s/^${ws}*//;p;}"
}

Rdconv_dir_or_files_to_LaTeX () {
  ## Convert Rd files in a dir or a list of Rd files to LaTeX, appending
  ## the result to OUTFILE.
  ## Usage:
  ##   Rdconv_dir_or_files_to_LaTeX OUTFILE DIR
  ##   Rdconv_dir_or_files_to_LaTeX OUTFILE FILES

  ${verbose} $@

  out="${1}"
  shift

  if test -d ${1}; then
    files=`ls ${1}/*.[Rr]d`
    if test -d ${1}/${OSdir}; then
      files="${files} `ls ${1}/${OSdir}/*.[Rr]d`"
    fi
    files=`LC_ALL=C echo ${files} | sort`
  else
    files="${@}"
  fi

  echo "Converting Rd files to LaTeX ..."

  for f in ${files}; do
    echo ${f}
    ${R_CMD} Rdconv -t latex ${f} >> ${out}
  done

}

is_bundle=no
file_sed='s/[_$]/\\&/g'

toc="\\Rdcontents{\\R{} topics documented:}"
if test -d "${1}"; then
  if test -f ${1}/DESCRIPTION; then
    if test -n "`grep '^Bundle:' ${1}/DESCRIPTION`"; then
      echo "Hmm ... looks like a package bundle"
      is_bundle=yes
      bundle_name=`get_dcf_field Bundle "${1}/DESCRIPTION"`
      bundle_pkgs=`get_dcf_field Contains "${1}/DESCRIPTION"`
      title=${title-"Bundle \`${bundle_name}'"}
    else
      echo "Hmm ... looks like a package"
      title=${title-"Package \`${1}'"}
      dir=${1}/man
    fi
  else
    if test -d ${1}/man; then
      dir=${1}/man
    else
      dir=${1}
    fi
    subj="all in \\file{`echo ${dir} | sed ${file_sed}`}"
  fi
else
  if test ${#} -gt 1 ; then
    subj=" etc.";
  else
    subj=
    toc=
  fi
  subj="\\file{`echo ${1} | sed ${file_sed}`}${subj}"
fi
title=${title-"\\R{} documentation}} \\par\\bigskip{{\\Large of ${subj}"}

## Prepare for building the documentation.
if test -f ${output}; then
  echo "file \`${output}' exists; please remove first"
  exit 1
fi
# pid is always 1000 on Windows sh.exe
#build_dir=.Rd2dvi${$}
build_dir=.Rd2dvi
if test -d ${build_dir}; then
  rm -rf ${build_dir} || echo "cannot write to build dir" && exit 2
fi
mkdir ${build_dir}
sed 's/markright{#1}/markboth{#1}{#1}/' \
  ${R_HOME}/doc/manual/Rd.sty > ${build_dir}/Rd.sty

## Rd2.tex part 1: header
cat > ${build_dir}/Rd2.tex <<EOF
\\documentclass[${R_PAPERSIZE}paper]{book}
\\usepackage[${R_RD4DVI-ae}]{Rd}
\\usepackage{makeidx}
\\makeindex
\\begin{document}
\\chapter*{}
\\begin{center}
{\\textbf{\\huge ${title}}}
\\par\\bigskip{\\large \\today}
\\end{center}
EOF

## Rd2.tex part 2: body
if test ${is_bundle} = no; then
  echo ${toc} >> ${build_dir}/Rd2.tex
  Rdconv_dir_or_files_to_LaTeX ${build_dir}/Rd2.tex ${dir-${@}}
else
  ## <FIXME>
  ## echo "\\tableofcontents{}" >> ${build_dir}/Rd2.tex
  echo ${toc} >> ${build_dir}/Rd2.tex
  ## </FIXME>
  for p in ${bundle_pkgs}; do
    echo "Bundle package: \`${p}'"
    (echo "\\chapter*{Package \`${p}'}"
      ## <FIXME>
      ## echo ${toc}
      ## </FIXME>
      ) >> ${build_dir}/Rd2.tex
    Rdconv_dir_or_files_to_LaTeX ${build_dir}/Rd2.tex ${1}/${p}/man
  done
fi

## Rd2.tex part 3: footer
cat >> ${build_dir}/Rd2.tex <<EOF
\\printindex
\\end{document}
EOF

echo "Creating ${out_ext} output from LaTeX ..."
cd ${build_dir}
${R_LATEXCMD-latex} Rd2
${R_MAKEINDEXCMD-makeindex} Rd2
${R_LATEXCMD-latex} Rd2
cd ${start_dir}
cp ${build_dir}/Rd2.${out_ext} ${output}
echo "Done"

if ${clean}; then
  rm -rf ${build_dir}
else
  echo "You may want to clean up by \`rm -rf ${build_dir}'"
fi
${preview} ${output}
exit 0

### Local Variables: ***
### mode: sh ***
### sh-indentation: 2 ***
### End: ***
