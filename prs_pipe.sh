#!/bin/bash

function PrintHelp() {

printf "\n
Syntax: ./prs_pipe.sh -f /path/2/vcf-files -a /path/2/model_a -b /path/2/model_b
                      -u /path/2/user_ids.tsv -o /path/2/output [-h] [-r]

required argument:
  -f <vcf folder>    All VCF-samples from 23andme| ancestry
  -o <output folder> Containing plink files and data frames for each sample
  -u <user_ids>      File containing the labeled samples [0,1]
  -a <model_a>       Path to model file A containing SNPS and BETA values
  -b <model_b>       Path to model file B containing SNPS and BETA values

optional arguments:
  -h        help menu
  -r        remove files created by PLINK (default: FALSE)
  -p        run PLINK analysis to quantify MAF adn HWE (default: FALSE)
\n\n" '\n'
exit
}

function CheckDirExists() {
   local func_DIR="$1"
   local func_CREATE="$2"
   if [ ! -d "$func_DIR" ]; then
			printf "$func_DIR does not exist..."
			if [ ! -z $func_CREATE ] && [ $func_CREATE == "Y" ]; then
				mkdir -v -p "$func_DIR"
			else
				printf "... and no directory created (set CheckDirExists DIR
								'Y' to automatically create if DIR does not exist)"
				exit
			fi
   fi
}

function PlinkStats() {
  local vcf=$1
  local pref=$2
  local r=$3
  echo "Perform Statistics QC with plink on $pref"
  plink --vcf $vcf --make-bed --out $pref
  echo "Minor allele frequencies (MAF): $pref"
  echo "The Hardy-Weinberg Equilibrium: $pref"
  plink --bfile $pref --freq --hardy --out $pref

  # Create Combinesd df with hwe and maf threshhold
  paste -d' ' $pref".hwe" <(awk '{print "\t" $5 "\t" $6}' $pref".frq") <(sed '/^#/d' $i  | awk '{print "\t" $1}' | awk 'NR==1{$1 = "POS" FS; print; next}{print}' ) > $pref"_unfiltred.txt"
  awk -F " " '{ if ( $10 >= 0.05 ) print $0 }' $pref"_unfiltred.txt"  | awk -F " " '{ if ( $9 >= 0.001 ) print $0 }' > $pref"_filtred.txt"

  echo $pref"_filtred.txt Created"
  CheckDirExists "${outputPath}/plink-files/$pf" "Y"
  mv $pf* "${outputPath}/plink-files/$pf/"
  
  if $r; then
    echo "Removing Files created by PLINK"
    find "${outputPath}/plink-files/$pf/" ! -name $pref'_filtred.txt' -delete
  fi

}

if [ $# -eq 0 ] || [ $1 == "-h" ] ; then
	PrintHelp
	exit
fi


# WORKING VARIABLES
snp2vcf=$PWD"/tools/snps2vcf.py"
compute_prs=$PWD"/tools/compute_prs.py"
evalR=$PWD"/tools/prs_evaluation.R"
rmPlinkFiles=false
runplink=false
modelA=""
modelB=""

# Initialize  working parameter
while getopts "hf:a:b:o:u:rp" OPTION;
do
	case ${OPTION} in
		h)
			PrintHelp
			;;
		f)
			rawFiles="$OPTARG"
			;;
		a)
			modelA="$OPTARG"
			;;
		b)
			modelB="$OPTARG"
			;;
		o)
			outputPath="$OPTARG"
			;;
	  u)
			userID="$OPTARG"
			;;
	  r)
			rmPlinkFiles=true
			;;
	  p)
			runplink=true
			;;
		*)
			echo "in extra argument"
			;;
	esac
done

# Create Required Directories
CheckDirExists ${outputPath} "Y"
CheckDirExists "${outputPath}/plink-files" "Y"
CheckDirExists "${outputPath}/quant" "Y"
CheckDirExists "${outputPath}/evaluation" "Y"


#################################
#########   PRS CALC   ##########
#################################
compute_prs=$PWD"/compute_prs.py"

for i in $rawFiles/*; do
  fn_="${i##*/}"
  pf=$(basename "${fn_%.*}")
  
  # QC Steps
  if $runplink; then
    PlinkStats $i $pf $rmPlinkFiles
    #df="${outputPath}/plink-files/$pf/"$pf"_filtred.txt"
  fi

  #Compute PRS
  CheckDirExists "${outputPath}/quant/$pf" "Y"
  python3 $compute_prs -vcf $i -m $modelA -o "${outputPath}/quant/$pf/" -snps
  python3 $compute_prs -vcf $i -m $modelB -o "${outputPath}/quant/$pf/" -snps
    
done

#################################
#########  EVALUATION  ##########
#################################

echo "Generate PRS data frame for both models ..."
wdir="${outputPath}/quant"

awk -F',' -v txt="" 'FNR>1 { print txt" "$1  }' $(find $wdir -type f -name "*model_a_PRS.txt" | sort) > "prs_model_a_temp.txt"
awk -F',' -v txt="" 'FNR>1 { print txt" "$1  }' $(find $wdir -type f -name "*model_b_PRS.txt" | sort) > "prs_model_b_temp.txt"
paste -d " " prs_model_b_temp.txt <(for i in $(find $wdir -type f -name "*a_PRS.txt" | sort); do echo $(basename $i) | cut -d "." -f 4 | cut -d "_" -f 1 ; done) > "model_b_sex_temp.txt"
join <(sort "prs_model_a_temp.txt") <(sort "model_b_sex_temp.txt") > "total_prs_temp.txt"
join -2 2 "total_prs_temp.txt" <(sort -k 2 $userID ) > "df_inter_temp.txt"

echo -e "SAMPLE\tPRS_model_a\tPRS_model_b\tsex_type\tcaffeine_addiction" | cat - df_inter_temp.txt > df_evaluate_temp.txt
awk -v OFS="\t" '$1=$1' df_evaluate_temp.txt > "${outputPath}/quant/prs_results_dataframe.txt"
rm -rf *_temp.txt
echo "${outputPath}/quant/prs_results_dataframe.txt Created and ready for evaluation!"

echo "Generate Evaluation Reports ..."
Rscript $evalR -i "${outputPath}/quant/prs_results_dataframe.txt" -o "${outputPath}/evaluation/"

echo "Pipe Completed!!!"
