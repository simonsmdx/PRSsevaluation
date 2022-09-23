# -- coding: utf-8 --
""""
@SimonPr
@date : 17.10.2022
"""

import snps
import os
import argparse
import datetime

def __main__():
    insnps, outvcf = parse_arg()
    s = read_inputed_snps(insnps)
    print(f"[{now()}] Exporting SNPs to vcf ...")
    saved_snps = s.save(f"{outvcf}.{s.determine_sex()}.vcf", vcf=True)

def now(start=datetime.datetime.now()):
    return str(datetime.datetime.now()-start)[:-4]

def parse_arg():
    parser = argparse.ArgumentParser(description='23andme|ancestry|my heritage to vcf',
                                     prog='Selection')
    parser. add_argument("-i", help="/path/2/input file",
                         default="missing",
                         required=True)
    parser.add_argument("-o", help="/path/2/output prefix for vcf",
                        default="missing",
                        required=True)
    args = vars(parser.parse_args())
    return args['i'], args['o']

def read_inputed_snps(intxtsnp):
    filename = os.path.split(intxtsnp)
    print(f"[{now()}] Reading {filename[1]} ...")
    _s = snps.SNPs(intxtsnp, assign_par_snps=True,
                            deduplicate=True,
                            deduplicate_MT_chrom=True,
                            deduplicate_XY_chrom=True)
    #chromosomes_remapped, chromosomes_not_remapped = s.remap(38)
    return _s


if __name__ == '__main__':
    __main__()
    print(f"[{now()}] Job Done!")
