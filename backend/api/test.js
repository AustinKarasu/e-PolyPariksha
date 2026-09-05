const bcrypt = require('bcryptjs');
const { query } = require('../src/config/db');

const STUDENTS = [
  {
    "sr": 1,
    "full_name": "Aakriti sharma",
    "guardian_name": "Pawan Kumar",
    "board_roll_no": "250810404001",
    "roll_no": "01",
    "college_id": "GPK-CE-25-01",
    "dob": "2008-02-05",
    "dob_pwd": "05022008",
    "email": "376aakriti@gmail.com",
    "address": "Village bhawarna tehsil palampur distt.kangra ,176083",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 2,
    "full_name": "Abansik",
    "guardian_name": "Anil kumar",
    "board_roll_no": "250810404002",
    "roll_no": "02",
    "college_id": "GPK-CE-25-02",
    "dob": "2007-09-23",
    "dob_pwd": "23092007",
    "email": "rajputabanshik@gmail.com",
    "address": "Vpo Bhanala teh. Shahpur distt. Kangra (HP) 176206",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 3,
    "full_name": "Abhay Dogra",
    "guardian_name": "Ajeet kumar",
    "board_roll_no": "250810404003",
    "roll_no": "03",
    "college_id": "GPK-CE-25-03",
    "dob": "2009-11-15",
    "dob_pwd": "15112009",
    "email": "abhay.dogra78743@gmail.com",
    "address": "S/O: Ajeet Kumar, Ward NO 3, Vill Bassa Lokwan Post Office Bhalakh, Bhalakh (412), Kangra, Himachal Pradesh - 176204",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 4,
    "full_name": "Abhay verma",
    "guardian_name": "Manju",
    "board_roll_no": "250810404004",
    "roll_no": "04",
    "college_id": "GPK-CE-25-04",
    "dob": "2010-11-08",
    "dob_pwd": "08112010",
    "email": "Vermag98822@gmail.com",
    "address": "Vill masyani, post office dhalwan, tehsil baldwara, distt. Mandi , himachal prasesh",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 5,
    "full_name": "Aditya",
    "guardian_name": "Vinod kumar",
    "board_roll_no": "250810404046",
    "roll_no": "05",
    "college_id": "GPK-CE-25-05",
    "dob": "2009-09-23",
    "dob_pwd": "23092009",
    "email": "a9aditya09@gmail.com",
    "address": "Balana, post office Balana, Tehsil - Sihunta, Distt. Chamba, 176207",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 7,
    "full_name": "Akshra Devi",
    "guardian_name": "Sh. Rajesh Kumar",
    "board_roll_no": "250810404005",
    "roll_no": "07",
    "college_id": "GPK-CE-25-07",
    "dob": "2009-11-18",
    "dob_pwd": "18112009",
    "email": "akshradevi181101@gmail.com",
    "address": "Village bassa pathania post office rit lower tehsil nurpur distt kangra pin code 176201",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 8,
    "full_name": "Anmol Saklani",
    "guardian_name": "Sh. Gopi chand",
    "board_roll_no": "250810404006",
    "roll_no": "08",
    "college_id": "GPK-CE-25-08",
    "dob": "2009-05-16",
    "dob_pwd": "16052009",
    "email": "anmolsaklani8@gmail.com",
    "address": "Vill. Chakroh po. Jhangi Teh. Sandhole distt. Mandi HP.",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 9,
    "full_name": "Anshul",
    "guardian_name": "Karam singh",
    "board_roll_no": "250810404007",
    "roll_no": "09",
    "college_id": "GPK-CE-25-09",
    "dob": "2009-04-22",
    "dob_pwd": "22042009",
    "email": "ks6391699@gmail.com",
    "address": "Vill Latwala PO Bagora teh palampur district kangra pin code 176059",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 10,
    "full_name": "Anshuman",
    "guardian_name": "Sanjay kumar",
    "board_roll_no": "250810404008",
    "roll_no": "10",
    "college_id": "GPK-CE-25-10",
    "dob": "2010-01-09",
    "dob_pwd": "09012010",
    "email": "neelamdevi22053@gmail.com",
    "address": "VPO Matour teh kangra distt kangra pin-code 176001",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 11,
    "full_name": "Arun Kumar",
    "guardian_name": "Sanjeev Kumar",
    "board_roll_no": "250810404009",
    "roll_no": "11",
    "college_id": "GPK-CE-25-11",
    "dob": "2008-08-15",
    "dob_pwd": "15082008",
    "email": "arunk050013@gmail.com",
    "address": "Village -Jadrangal Post Office Kand Kardiyana District Kangra",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 12,
    "full_name": "Arush patiyal",
    "guardian_name": "Arvind kumar",
    "board_roll_no": "250810404010",
    "roll_no": "12",
    "college_id": "GPK-CE-25-12",
    "dob": "2009-10-21",
    "dob_pwd": "21102009",
    "email": "Patialarush7@gmail.com",
    "address": "VPO bhoda lounti, palampur, kangra, 176092",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 13,
    "full_name": "Aryan",
    "guardian_name": "Raghuvir Singh",
    "board_roll_no": "250810404011",
    "roll_no": "13",
    "college_id": "GPK-CE-25-13",
    "dob": "2010-10-23",
    "dob_pwd": "23102010",
    "email": "aryanaru7301@gmail.com",
    "address": "VILLAGE ROPARI POST OFFICE ROPARI TEHSIL BARSAR,  Hamirpur, Himachal Pradesh, 176041",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 14,
    "full_name": "Aryan",
    "guardian_name": "Sushil kumar",
    "board_roll_no": "250810404012",
    "roll_no": "14",
    "college_id": "GPK-CE-25-14",
    "dob": "2008-06-21",
    "dob_pwd": "21062008",
    "email": "ac6959782@gmail.com",
    "address": "VPO Pathiar, tehsil-Nagrota bagwan , Distt- kangra, Pin Code - 176047",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 15,
    "full_name": "Ayush",
    "guardian_name": "Late Rajeev Kumar",
    "board_roll_no": "250810404013",
    "roll_no": "15",
    "college_id": "GPK-CE-25-15",
    "dob": "2004-04-03",
    "dob_pwd": "03042004",
    "email": "ayushrana0204@gmail.com",
    "address": "Village Ghaneta Post office Darang Pin code -170606",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 16,
    "full_name": "Divyansh",
    "guardian_name": "Joginder kumar",
    "board_roll_no": "250810404014",
    "roll_no": "16",
    "college_id": "GPK-CE-25-16",
    "dob": "2008-08-09",
    "dob_pwd": "09082008",
    "email": "anmolnarotra@gmail.com",
    "address": "Vill.- Mandeli,p/o- Muhal, Tehsil- Dehra, District- kangra",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 17,
    "full_name": "Divyansh Koundal",
    "guardian_name": "Dina Nath",
    "board_roll_no": "250810405015",
    "roll_no": "17",
    "college_id": "GPK-CE-25-17",
    "dob": "2009-12-13",
    "dob_pwd": "13122009",
    "email": "koundaldivyansh75@gmail.com",
    "address": "V.P.O Sahoura, tehsil,Distt kangra 176209",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 18,
    "full_name": "Harshit",
    "guardian_name": "Rajesh",
    "board_roll_no": "250810404016",
    "roll_no": "18",
    "college_id": "GPK-CE-25-18",
    "dob": "2009-01-02",
    "dob_pwd": "02012009",
    "email": "harshitdh127@gmail.com",
    "address": "VPO Dhodhamb, PO Dhodhamb, Tehsil Shahpur, Distt Kangra, 176217 Kangra,",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 20,
    "full_name": "Ishant dogra",
    "guardian_name": "Sh. Ajay Kumar",
    "board_roll_no": "250810404018",
    "roll_no": "20",
    "college_id": "GPK-CE-25-20",
    "dob": "2010-11-22",
    "dob_pwd": "22112010",
    "email": "ishantdogra78@gmail.com",
    "address": "S/O Ajay kumar , village Bhiambi , Tehsil bangana, VTC : Bhiambi (16/3), PO Bhiambi, Sub district :Bangana , District : Una , State : Himachal Pradesh, Pin code: 177038",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 21,
    "full_name": "Ishita sugha",
    "guardian_name": "Sh Rajesh sugha",
    "board_roll_no": "250810404019",
    "roll_no": "21",
    "college_id": "GPK-CE-25-21",
    "dob": "2010-02-06",
    "dob_pwd": "06022010",
    "email": "anjnasugha@gmail.com",
    "address": "Himachal Pradesh district kangra vpo teh jaisinghpur",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 22,
    "full_name": "Kajal",
    "guardian_name": "Ramesh Chand",
    "board_roll_no": "250810404020",
    "roll_no": "22",
    "college_id": "GPK-CE-25-22",
    "dob": "2007-11-28",
    "dob_pwd": "28112007",
    "email": "kajalchaudhary24273@gmail.com",
    "address": "Village Henja post office Bhawarna tehsil Palampur district Kangra Himachal Pradesh 176083",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 23,
    "full_name": "Lovepreet singh",
    "guardian_name": "Jagir singh",
    "board_roll_no": "8580967734",
    "roll_no": "23",
    "college_id": "GPK-CE-25-23",
    "dob": "2009-01-24",
    "dob_pwd": "24012009",
    "email": "lovepreeetsingh9876@gmail.com",
    "address": "Ward no.2 vpo jalari tehsil and district kangra 176038",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 24,
    "full_name": "Manan sharma",
    "guardian_name": "Dinesh kumar",
    "board_roll_no": "250810404022",
    "roll_no": "24",
    "college_id": "GPK-CE-25-24",
    "dob": "2010-01-10",
    "dob_pwd": "10012010",
    "email": "manansharma.ce@gpkangra.edu",
    "address": "176215",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 25,
    "full_name": "Manas bhardwaj",
    "guardian_name": "Sanjeet kumar",
    "board_roll_no": "9418341180",
    "roll_no": "25",
    "college_id": "GPK-CE-25-25",
    "dob": "2008-09-17",
    "dob_pwd": "17092008",
    "email": "manasbhardwaj802@gmail.com",
    "address": "Jangal beri Vpo Jangal beri Tehsil Sujanpur tihra Distt Hamirpur  176109",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 26,
    "full_name": "Manisha Dhiman",
    "guardian_name": "Vinod kumar",
    "board_roll_no": "250810404023",
    "roll_no": "26",
    "college_id": "GPK-CE-25-26",
    "dob": "2008-02-20",
    "dob_pwd": "20022008",
    "email": "manishadhiman0208@gmail.com",
    "address": "Village -Tajiar , PO-Maharal ,Tehsil-Dhatwal, Distt- Hamirpur, Pin Code-176049",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 27,
    "full_name": "Mayank bhaskar",
    "guardian_name": "Nek Ram",
    "board_roll_no": "250810404024",
    "roll_no": "27",
    "college_id": "GPK-CE-25-27",
    "dob": "2010-01-29",
    "dob_pwd": "29012010",
    "email": "mayankbhaskar106@gmail.com",
    "address": "Vill.Mohin PO.Gopalpur Teh.Sarkaghat Distt.Mandi Pin.175007",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 28,
    "full_name": "Muskan",
    "guardian_name": "Subhash chand",
    "board_roll_no": "250810404025",
    "roll_no": "28",
    "college_id": "GPK-CE-25-28",
    "dob": "2006-05-08",
    "dob_pwd": "08052006",
    "email": "Muskannath41@gmail.com",
    "address": "Vpo dohb tehsil shahpur district kangra pin code 176206",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 29,
    "full_name": "Paras",
    "guardian_name": "Sanjay Kumar",
    "board_roll_no": "250810404027",
    "roll_no": "29",
    "college_id": "GPK-CE-25-29",
    "dob": "2009-06-24",
    "dob_pwd": "24062009",
    "email": "paraschoudhary0010@gmail.com",
    "address": "Kir chamba.... Hatwas... Nagrota Bagwan....Kangra..176047",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 30,
    "full_name": "Radhika",
    "guardian_name": "Munesh",
    "board_roll_no": "250810404029",
    "roll_no": "30",
    "college_id": "GPK-CE-25-30",
    "dob": "2010-04-14",
    "dob_pwd": "14042010",
    "email": "rpathania775@gmail.com",
    "address": "Vill. Bhalyandra, PO. Bhararu, Tehsil Joginder Nager, Distt. Mandi, Pin code(175015)",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 31,
    "full_name": "Raj Sharma",
    "guardian_name": "Sanjay Sharma",
    "board_roll_no": "250810404044",
    "roll_no": "31",
    "college_id": "GPK-CE-25-31",
    "dob": "2009-09-21",
    "dob_pwd": "21092009",
    "email": "rajopvlogs123@gmail.com",
    "address": "Palampur 176061, Ghughar Near Shiv Nala Mandir",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 32,
    "full_name": "Ridhima choudhary",
    "guardian_name": "Desh raj",
    "board_roll_no": "250810404030",
    "roll_no": "32",
    "college_id": "GPK-CE-25-32",
    "dob": "2008-06-10",
    "dob_pwd": "10062008",
    "email": "ridhimachaudhary007@gmail.com",
    "address": "Village Mundla, Post office Sunehar, tehsil Nagrota Bagwan  district Kangra (H.P) pincode- 176056",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 33,
    "full_name": "Rudransh singh rana",
    "guardian_name": "Amit kumar rana",
    "board_roll_no": "250810404031",
    "roll_no": "33",
    "college_id": "GPK-CE-25-33",
    "dob": "2009-05-04",
    "dob_pwd": "04052009",
    "email": "rudranshrana30@gmail.com",
    "address": "VPO Tatehal,palampur,kangra,176103",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 34,
    "full_name": "Sahil Guleria",
    "guardian_name": "Hans Raj",
    "board_roll_no": "250810404032",
    "roll_no": "34",
    "college_id": "GPK-CE-25-34",
    "dob": "2007-06-01",
    "dob_pwd": "01062007",
    "email": "sahilguleria722@gmail.com",
    "address": "Vill. jol,PO. bhali,Teh.jawali, Distt.kangra,176206",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 35,
    "full_name": "Sanjeev kumar",
    "guardian_name": "Vinod kumar",
    "board_roll_no": "250810404033",
    "roll_no": "35",
    "college_id": "GPK-CE-25-35",
    "dob": "2007-04-22",
    "dob_pwd": "22042007",
    "email": "sanjeevfozlli@gmail.com",
    "address": "VPO fozal distt kullu Himachal Pradesh pincode 175129",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 36,
    "full_name": "Sanvi Mahajan",
    "guardian_name": "Sh. Pankaj Mahajan",
    "board_roll_no": "250810404045",
    "roll_no": "36",
    "college_id": "GPK-CE-25-36",
    "dob": "2010-03-07",
    "dob_pwd": "07032010",
    "email": "sanvimahajan2009@gmail.com",
    "address": "Village samote p.o samote teh shuinta dist. Chamba pin code 176207",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 37,
    "full_name": "Sheetal",
    "guardian_name": "Satish Kumar",
    "board_roll_no": "250810404034",
    "roll_no": "37",
    "college_id": "GPK-CE-25-37",
    "dob": "2009-08-07",
    "dob_pwd": "07082009",
    "email": "sinum319@gmail.com",
    "address": "Vill Ramehar PO lower khera teh. Palampur distt. Kangra",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 38,
    "full_name": "Shivam",
    "guardian_name": "Mr.vinod kumar",
    "board_roll_no": "250810404035",
    "roll_no": "38",
    "college_id": "GPK-CE-25-38",
    "dob": "2009-02-18",
    "dob_pwd": "18022009",
    "email": "shivamchoudhary8138@gmail.com",
    "address": "V.p.o lwer sukkar tehsil dharamshala distt kanga",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 39,
    "full_name": "Shivam Sharma",
    "guardian_name": "Purushotam Sharma",
    "board_roll_no": "250810404047",
    "roll_no": "39",
    "college_id": "GPK-CE-25-39",
    "dob": "2008-06-01",
    "dob_pwd": "01062008",
    "email": "shivusharma008123@gmail.com",
    "address": "V.p.o:- Bari majherwan, Teh.:- Ghumarwin, Distt.:- Bilaspur, 174021",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 40,
    "full_name": "Shivani",
    "guardian_name": "Shri Jagdish kumar",
    "board_roll_no": "250810404036",
    "roll_no": "40",
    "college_id": "GPK-CE-25-40",
    "dob": "2010-07-09",
    "dob_pwd": "09072010",
    "email": "shivanibhatia.0917@gmail.com",
    "address": "Vill balah PO kotla tehsil Jawali district kangra Pin code 176205",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 41,
    "full_name": "Sujal Thakur",
    "guardian_name": "Sanjeev Kumar",
    "board_roll_no": "80910889677",
    "roll_no": "41",
    "college_id": "GPK-CE-25-41",
    "dob": "2008-11-08",
    "dob_pwd": "08112008",
    "email": "sujalthakur7701@gmail.com",
    "address": "Vill gharwasra po dhalwan teh balwara disst mandi hp 175004",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 42,
    "full_name": "Surya Kumar koundal",
    "guardian_name": "Parveen Kumar",
    "board_roll_no": "250810404040",
    "roll_no": "42",
    "college_id": "GPK-CE-25-42",
    "dob": "2009-08-06",
    "dob_pwd": "06082009",
    "email": "koundalsurya79@gmail.com",
    "address": "C/O: Parveen Kumar, Village Tanda, Tehsil Palama Saralu (254), PO: Rajpur, DIST: Kangra,  Himachal Pradesh - 176061",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 43,
    "full_name": "Swastik Naryal",
    "guardian_name": "Sanjeev Kumar",
    "board_roll_no": "250810404041",
    "roll_no": "43",
    "college_id": "GPK-CE-25-43",
    "dob": "2010-03-03",
    "dob_pwd": "03032010",
    "email": "swastiknaryal@gmail.com",
    "address": "VPO Samloti Near PNB Bank",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 44,
    "full_name": "Tamanna Sharma",
    "guardian_name": "Anil Kumar",
    "board_roll_no": "250810404049",
    "roll_no": "44",
    "college_id": "GPK-CE-25-44",
    "dob": "2009-07-29",
    "dob_pwd": "29072009",
    "email": "Tamanna223sh@gmail.com",
    "address": "Nalla shiv mandir , Sugghar ,V/PO Palampur, Tehsil- Palampur, Distt Kangra, pincode-176061",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 45,
    "full_name": "Utkarsh",
    "guardian_name": "Raj Kumar",
    "board_roll_no": "250810404050",
    "roll_no": "45",
    "college_id": "GPK-CE-25-45",
    "dob": "2010-03-20",
    "dob_pwd": "20032010",
    "email": "utkarshu874@gmail.com",
    "address": "Near Niwal School, Ward No. 6, Post Office Bhawarna, Tehsil Palampur, Badghawar (276), P.O. Bhawarna, Dist. Kangra, Himachal Pradesh - 176083.",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 46,
    "full_name": "Vanshik choudhary",
    "guardian_name": "Mr Mila Chand",
    "board_roll_no": "240810404045",
    "roll_no": "46",
    "college_id": "GPK-CE-25-46",
    "dob": "2008-09-22",
    "dob_pwd": "22092008",
    "email": "v324300@gmail.com",
    "address": "Ward No. 3 Tehsil Palampur VTC: Padehr (104) P.O.: Ballah Sub-District: Palampur District: Kangra State: Himachal Pradesh PIN Code: 176064",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 48,
    "full_name": "YASHITA MEHRA",
    "guardian_name": "SANDEEP KUMAR",
    "board_roll_no": "250810404042",
    "roll_no": "48",
    "college_id": "GPK-CE-25-48",
    "dob": "2009-09-01",
    "dob_pwd": "01092009",
    "email": "Yashitamehra107@gmail.com",
    "address": "VPO banuri tehsil palampur distt kangra, 176061",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  },
  {
    "sr": 49,
    "full_name": "Yogesh Raj",
    "guardian_name": "Khem Raj",
    "board_roll_no": "250810404043",
    "roll_no": "49",
    "college_id": "GPK-CE-25-49",
    "dob": "2010-09-09",
    "dob_pwd": "09092010",
    "email": "rajyogesh2024@gmail.com",
    "address": "Parour,Po - Parour , Sulah, kangra,hp,176064",
    "branch_id": 1,
    "semester": 3,
    "admission_year": 2025
  }
];

module.exports = async (req, res) => {
  try {
    // 1. Delete events, attempts, sessions for students to be removed
    // Keep admin (role = 'admin') and student Aayan Parmar (board_roll_no IN ('208140404002', '240810404002'))
    const delEvents = await query(`
      DELETE FROM exam_events
      WHERE student_id IN (
        SELECT id FROM users
        WHERE role = 'student'
          AND board_roll_no NOT IN ('208140404002', '240810404002')
      )
      RETURNING id
    `);

    const delAttempts = await query(`
      DELETE FROM test_attempts
      WHERE student_id IN (
        SELECT id FROM users
        WHERE role = 'student'
          AND board_roll_no NOT IN ('208140404002', '240810404002')
      )
      RETURNING id
    `);

    const delSessions = await query(`
      DELETE FROM auth_sessions
      WHERE user_id IN (
        SELECT id FROM users
        WHERE role = 'student'
          AND board_roll_no NOT IN ('208140404002', '240810404002')
      )
      RETURNING id
    `);

    const delUsers = await query(`
      DELETE FROM users
      WHERE role = 'student'
        AND board_roll_no NOT IN ('208140404002', '240810404002')
      RETURNING id, full_name, board_roll_no
    `);

    // Clear login lockouts
    await query('DELETE FROM login_failures');

    // 2. Insert or update the 46 students
    const processed = [];
    for (const s of STUDENTS) {
      const passwordHash = await bcrypt.hash(s.dob_pwd, 12);

      const existing = await query(
        'SELECT id FROM users WHERE role = $1 AND (board_roll_no = $2 OR college_id = $3 OR email = $4)',
        ['student', s.board_roll_no, s.college_id, s.email]
      );

      let record;
      if (existing.length > 0) {
        const updated = await query(
          `UPDATE users SET
            full_name = $1,
            guardian_name = $2,
            email = $3,
            college_id = $4,
            password_hash = $5,
            branch_id = $6,
            dob = $7,
            semester = $8,
            roll_no = $9,
            board_roll_no = $10,
            address = $11,
            admission_year = $12,
            college_name = 'Govt. Polytechnic Kangra',
            course_name = 'Computer Engg',
            must_change_credentials = TRUE,
            is_active = TRUE,
            updated_at = CURRENT_TIMESTAMP
           WHERE id = $13
           RETURNING id, full_name, board_roll_no, college_id, dob, email`,
          [
            s.full_name,
            s.guardian_name,
            s.email,
            s.college_id,
            passwordHash,
            s.branch_id,
            s.dob,
            s.semester,
            s.roll_no,
            s.board_roll_no,
            s.address,
            s.admission_year,
            existing[0].id
          ]
        );
        record = updated[0];
      } else {
        const inserted = await query(
          `INSERT INTO users (
            full_name, guardian_name, email, college_id, password_hash,
            role, branch_id, dob, semester, roll_no, board_roll_no,
            college_name, course_name, address, admission_year,
            must_change_credentials, is_active
          ) VALUES (
            $1, $2, $3, $4, $5,
            'student', $6, $7, $8, $9, $10,
            'Govt. Polytechnic Kangra', 'Computer Engg', $11, $12,
            TRUE, TRUE
          )
          RETURNING id, full_name, board_roll_no, college_id, dob, email`,
          [
            s.full_name,
            s.guardian_name,
            s.email,
            s.college_id,
            passwordHash,
            s.branch_id,
            s.dob,
            s.semester,
            s.roll_no,
            s.board_roll_no,
            s.address,
            s.admission_year
          ]
        );
        record = inserted[0];
      }
      processed.push(record);
    }

    // Fetch all users to verify
    const allUsers = await query(
      `SELECT id, full_name, role, board_roll_no, college_id, roll_no, semester, branch_id, must_change_credentials, is_active
       FROM users
       ORDER BY role, id`
    );

    res.json({
      status: 'success',
      deletedUsersCount: delUsers.length,
      deletedUsers: delUsers,
      deletedAttemptsCount: delAttempts.length,
      deletedEventsCount: delEvents.length,
      processedCount: processed.length,
      allUsersCount: allUsers.length,
      allUsers
    });
  } catch (err) {
    res.status(500).json({ error: err.message, stack: err.stack });
  }
};
