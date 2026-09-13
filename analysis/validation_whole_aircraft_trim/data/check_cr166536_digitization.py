"""Check source coverage, selected visual anchors and guarded table-reader behavior."""
import json
import hashlib
import platform
import sys
import unittest
from collections import Counter, defaultdict
from cr166536_tables import ROOT, TableDatabase, TableError, token

class DigitizationChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.db=TableDatabase()

    def test_required_table_coverage(self):
        expected={
            '3-I':31,'3-II':19,'3-III':31,'3-IV':19,'3-V':31,'3-VI':35,'3-VII':19,'3-VIII':19,'3-IX':19,
            '4-I':140,'4-II':318,'4-III':105,'4-IV':282,'4-VI':8,'4-VII':8,'4-VIII':20,
            '4-IX':12,'4-X':12,'4-XI':8,'4-XII':4,'4-XIII':12,'4-XIV':12,'4-XV':14,'4-XVI':7,
            '5-I':392,'5-II':124,'5-III':196,'5-IV':6,'5-VI':8,'5-VII':5,
            '6-I':250,'6-II':124,'6-III':188,'6-IV':144,'6-V':144,'6-VI':144,'6-VII':144,'6-VIII':56,
            '5/constants':12,'6/constants':23}
        expected.update({'4-V('+c+')':56 for c in 'abcde'})
        expected.update({'5-V(a)':108,'5-V(b)':108,'5-V(c)':54})
        for table,count in expected.items():
            with self.subTest(table=table):self.assertEqual(len(self.db.by_table[table]),count)
        self.assertEqual(len(self.db.cells),4357)
        self.assertEqual(sum(c['value'] is not None for c in self.db.cells),3926)

    def test_legacy_tables_preserved(self):
        expected={'1-I':12,'1-II/endurance':27,'1-II/sideward':8,'1-III':10,
                  '2-I(a)':128,'2-I(b)':128,'2-I(c)':128,'2-I(d)':1,'2-II':50,
                  '8a-I':10,'8a-II':30,'8a-III':10,'8a-IV':20,'8a-V':30,
                  '8a-VI':21,'8a-VII':7,'8a-VIII':7,'4/constants':35}
        for table,count in expected.items():self.assertEqual(len(self.db.by_table[table]),count,table)

    def test_all_statuses_values_and_pages(self):
        missing=Counter()
        for c in self.db.cells:
            self.assertEqual(c['printed_page'],'B-'+str(int(c['pdf_page'])-350),c)
            self.assertTrue(c['status'],c)
            if c['raw_value']!='':
                self.assertIsNotNone(c['value'],c)
                self.assertFalse('NOT_DEFINED' in c['status'] or 'REFERENCE' in c['status'],c)
            else:
                self.assertIsNone(c['value'],c)
                self.assertTrue(any(s in c['status'] for s in ('NOT_DEFINED','REFERENCE','SOURCE_BLANK','SOURCE_DASH')),c)
                missing[c['status']]+=1
        self.assertEqual(sum(v for k,v in missing.items() if 'NOT_DEFINED' in k),360)
        self.assertEqual(sum(v for k,v in missing.items() if 'REFERENCE' in k),62)
        self.assertEqual(missing['SOURCE_BLANK']+missing['SOURCE_DASH'],9)

    def test_duplicate_nodes_do_not_disagree(self):
        keys=defaultdict(list)
        for c in self.db.cells:
            key=(c['table'],tuple(sorted((k,token(v)) for k,v in c['coordinates'].items())))
            keys[key].append(c)
        for key,cells in keys.items():
            values={c['value'] for c in cells if c['value'] is not None}
            self.assertLessEqual(len(values),1,(key,cells))
            if values:self.assertFalse(any('NOT_DEFINED' in c['status'] for c in cells),(key,cells))

    def anchor(self,table,expected,**selectors):
        cells=self.db.select(table,**selectors)
        self.assertEqual({c['value'] for c in cells},{expected},(table,selectors,cells))

    def test_independently_read_source_anchors(self):
        # Fixed from original page images, including original asymmetric values.
        self.anchor('4-V(a)',0,row_value=-90,flap_setting='0/0')
        self.anchor('4-V(e)',6.15,row_value=0,flap_setting='75/47')
        self.anchor('4-VI',-.136,row_value=0,flap_setting='20/12.5|40/25|75/47')
        self.anchor('4-VIII',-.19,row_value=90,flap_setting='75/47')
        self.anchor('4-XII',.00476,flap_setting_code='X_FL3')
        self.anchor('4-XIII',-.00003,flap_setting_code='X_FL4',mast_angle_deg=0)
        self.anchor('4-XIV',-.087,flap_setting_code='X_FL4',mast_angle_deg=30)
        self.anchor('4-XV',13.25,row_value=55)
        self.anchor('4-XVI',.95,row_value=40)
        self.anchor('5-I',1.54,alpha_deg=-130,elevator_deg=20)
        self.anchor('5-I',-1.45,alpha_deg=130,elevator_deg=-20)
        self.anchor('5-III',.045,alpha_deg=-8,mach_label='.6')
        self.anchor('5-III',.065,alpha_deg=8,mach_label='.6')
        self.anchor('6-II',-.375,row_key=-18,col_key='0.6')
        self.anchor('6-V',1.1,mast_deg=0,row_key='>=28.0',col_key=8)
        self.anchor('6-VII',1.8,mast_deg=0,row_key=-3,col_key='0 & 4')
        self.anchor('6-VIII',-.5,row_key=40,col_key=0)

    def test_unit_and_axis_corrections(self):
        self.assertEqual({c['unit'] for c in self.db.by_table['3-VIII']},{'ft3'})
        self.assertEqual({c['unit'] for c in self.db.by_table['4-VIII']},{'dimensionless'})
        self.assertEqual({c['raw']['unit'] for c in self.db.by_table['4-VIII']},{'1/rad_AS_PRINTED'})
        self.assertEqual({c['unit'] for c in self.db.by_table['4-XV']},{'ft^2'})
        self.assertTrue(all('PYL' in c['raw']['row_key'] for c in self.db.by_table['4-XVI']))
        self.assertEqual(self.db.select('5/constants',parameter='C_LH_beta')[0]['unit'],'1/deg')
        self.assertEqual(self.db.select('6/constants',parameter='d_sigma_d_p_hat')[0]['unit'],'dimensionless')

    def test_reference_resolution_and_full_angle_domain(self):
        for angle in (0,10,100,-180):
            h=self.db.curve('5-II','alpha_deg',angle,elevator_deg=0,mach_label='0-0.2')
            hsource=self.db.curve('5-I','alpha_deg',angle,elevator_deg=0)
            self.assertEqual(h['value'],hsource['value'])
            self.assertTrue(h['operation'].startswith('explicit_source_reference'))
            v=self.db.curve('6-II','row_key',angle,col_key='0-0.2')
            vsource=self.db.curve('6-I','row_key',angle,col_key=0)
            self.assertEqual(v['value'],vsource['value'])
        self.assertIn('interpolation',self.db.curve('5-I','alpha_deg',0,elevator_deg=0)['operation'])
        self.assertIn('interpolation',self.db.curve('6-I','row_key',0,col_key=0)['operation'])

    def test_refuse_undefined_extrapolation_ambiguous_and_group_axis(self):
        bad=[lambda:self.db.curve('5-II','alpha_deg',30,mach_label='.6'),
             lambda:self.db.curve('6-II','row_key',30,col_key='0.6'),
             lambda:self.db.curve('6-II','row_key',22,col_key='0.6'),
             lambda:self.db.curve('5-I','alpha_deg',181,elevator_deg=0),
             lambda:self.db.curve('5-I','alpha_deg',0),
             lambda:self.db.curve('6-IV','row_key',0,mast_deg=0,col_key=8),
             lambda:self.db.select('4-II',flap_setting='unknown')]
        for call in bad:
            with self.subTest(call=call),self.assertRaises(TableError):call()

    def test_interpolation_is_not_reported_as_source_data(self):
        out=self.db.curve('4-V(e)','row_value',2,flap_setting='0/0')
        self.assertAlmostEqual(out['value'],(3.15+4.68)/2)
        self.assertEqual(out['bracket'],[0,4])
        self.assertEqual(out['operation'],'linear_interpolation_not_source_sample')
        self.assertTrue(out['source_rows'])

if __name__=='__main__':
    suite=unittest.defaultTestLoader.loadTestsFromTestCase(DigitizationChecks)
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    report=dict(pass_all=result.wasSuccessful(),test_groups=result.testsRun,
                failures=len(result.failures),errors=len(result.errors),python=sys.version,
                executable=sys.executable,platform=platform.platform(),
                scope='CSV coverage, selected source anchors and reader behavior; no aircraft simulation')
    report['source_csv_sha256']={f['file']:f['sha256'] for f in TableDatabase().files}
    report['reader_sha256']=hashlib.sha256((ROOT/'cr166536_tables.py').read_bytes()).hexdigest()
    report['check_script_sha256']=hashlib.sha256((ROOT/'check_cr166536_digitization.py').read_bytes()).hexdigest()
    (ROOT/'CR166536_CHECK_RESULTS.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    sys.exit(0 if result.wasSuccessful() else 1)
