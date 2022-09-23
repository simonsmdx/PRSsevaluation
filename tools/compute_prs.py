# -- coding: utf-8 --
""""
@date : 17.10.2022
"""

import pandas as pd
import datetime, os, argparse


def main():
    path_genotype, path_model, path_output, include_snp = parse_arg()
    sample = path_genotype[path_genotype.rfind("/") + 1: path_genotype.find(".vcf")]
    sample_name=sample.rsplit('.', 1)[0]
    model_name=path_model[path_model.rfind("/") + 1: path_model.find(".tsv")]
    df_effect_size, df_all_snp, model = parse_input_model(path_genotype, path_model, sample)

    if include_snp:
        df_all_snp.to_csv(path_output + sample_name + "_" + model_name + "_df.txt", sep='\t', index=False)
    else:
        df_effect_size.to_csv(path_output + sample_name + "_" + model_name + "_df.txt", sep='\t', index=False)

    prs_df = compute_prs(sample_name, df_all_snp, model_name)
    prs_df.to_csv(path_output + sample + "_" + model_name + "_PRS.txt", sep='\t', index=False)


def now(start=datetime.datetime.now()):
    return str(datetime.datetime.now() - start)[:-4]


def parse_arg():
    parser = argparse.ArgumentParser(
        description='Description of your program')
    parser.add_argument('-vcf', type=str,
                        help='/path/2/vcf file',
                        required=True)
    parser.add_argument('-m', type=str,
                        help='/path/2/model',
                        required=True)
    parser.add_argument('-o', type=str,
                        help='/path/2/outputdir',
                        required=True)
    parser.add_argument('-snps', action='store_true')

    args = vars(parser.parse_args())
    return args['vcf'], args['m'], args['o'], args['snps']


def parse_input_model(path_genotype, path_model, sample):

    # Extract SNPs from vcf file to DataFrame
    filename_model = os.path.split(path_model)[1]
    print(f"[{now()}] Reading  {sample}....")
    data_vcf = read_vcf(path_genotype)
    header = data_vcf[0].strip().split("\t")
    vcf_info = [d.strip().split("\t") for d in data_vcf[1:]]
    vcf_file = pd.DataFrame(vcf_info, columns=header)

    # Extract SNPs and BETA from model
    print(f"[{now()}] Reading {filename_model}....")
    _model = pd.read_csv(path_model, sep='\t', index_col=False)
    df_common_rs = vcf_file[vcf_file.ID.isin(_model["snp_id"].tolist())]
    df_include_eff = pd.merge(df_common_rs, _model, left_on="ID",
                              right_on="snp_id").drop("snp_id", axis=1)

    # Get SNPS that are in model but not in sample
    ll = df_common_rs["ID"].tolist()
    ll2 = _model["snp_id"].tolist()
    list_dif = (list(set(ll2) - set(ll)))

    # Add SNPs from model with 0 value that are not in sample
    _df = pd.DataFrame()
    _df[list(df_include_eff.columns)] = "NAN"
    _df["ID"] = list_dif
    df_all_snp = pd.concat([df_include_eff, _df])
    df_final = df_all_snp.fillna("0")
    df_f = df_final.reset_index(drop=True)
    print(f"[{now()}] Exporting dataframe with"
          f" specific rsID and effect size for {sample}....")
    return df_include_eff, df_f, _model


def read_vcf(_path):
    with open(_path, "r") as f:
        lines = f.readlines()
        chr_index = [i for i, line in enumerate(lines)
                     if line.strip().startswith("#CHROM")]
        f.close()
    return lines[chr_index[0]:]


def compute_prs(sample, df, model_name):
    # PLINK Default  PRS Formula
    print(f"[{now()}] Calculating PRS for {sample}....")
    nr_total_snp = df[df.columns[0]].count()
    sum_neg, sum_pos = 0, 0
    nr_eff_alleles = (df["REF"] != 0).sum()

    for j in df["effect_size"].astype(float):
        if j < 0:
            sum_neg = sum_neg + (-(j*nr_eff_alleles))
        else:
            sum_pos = sum_pos + (j*nr_eff_alleles)
    prs = (sum_pos+sum_neg)/(nr_total_snp*2)
    data = {"file_link": [sample], "PRS-"+model_name : prs}
    prs_df=pd.DataFrame(data)
    print(f"[{now()}] Exporting PRS Results for {sample}....")
    return prs_df


if __name__ == "__main__":
    main()

