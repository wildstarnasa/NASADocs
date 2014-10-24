  local CharacterNames = {}

function CharacterNames:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function CharacterNames:Init()
	Apollo.RegisterAddon(self)
end

local tExileFirstNameMale = { "Aron", "Abram", "Abe", "Alan", "Allen", "Albert", "Alonzo", "Ambrose", "Amon", "Amos", "Andie", "Arch", "Asa", "Barnabas", "Barney", "Bart", "Ben", "Bennet", "Bern", "Bertrom", "Bertal", "Byford", "Byrone", "Calven", "Cris", "Clem", "Clent", "Clynt", "Cole", "Perrie", "Dan", "Davon", "Davan", "Devan", "Devyn", "Edmund", "Edward", "Edwin", "Eldon", "Eli", "Enett", "Emmett", "Enoch", "Ezekiel", "Ezra", "Gabe", "Garrett", "Jorge", "Gideon", "Gilvert", "Gil", "Gus", "Harland", "Harison", "Harolt", "Hiran", "Hiram", "Izaac", "Jakeb", "Jake", "Jaymes", "Jazper", "Jeck", "Jed", "Jeb", "Jep", "Jesse", "Jole", "Jon", "Leander", "Les", "Lowis", "Levi", "Lucas", "Luke", "Luther", "Mathis", "Mark", "Martyn", "Maxwell", "Merrill", "Meriwether", "Mike", "Micah", "Morgan", "Moris", "Nathon", "Nate", "Nat", "Ned", "Newton", "Nick", "Obediah", "Orvil", "Oscor", "Owen", "Ralf", "Ray", "Rubin", "Roebert", "Ritch", "Rufis", "Rufos", "Samel", "Sam", "Seth", "Silas", "Simon", "Stan", "Stephen", "Thad", "Thadd", "Thom", "Tomis", "Tom", "Theo", "Ted", "Timothi", "Tim", "Victer", "Waltor", "Waren", "Will", "Willie", "Zebulon", "Zedock", "Zeke" 
}

local tExileFirstNameFemale = { "Abigale", "Abby", "Ada", "Adella", "Allie", "Almyra", "Alva", "Amela", "Ayn", "An", "Ann", "Arrah", "Becki", "Bess", "Bessie", "Charlot", "Clayre", "Cynthea", "Dorothea", "Dot", "Edyth", "Edwina", "Ella", "Elayne", "Ellie", "Elyza", "Lyza", "Liza", "Lizi", "Ema", "Etty", "Evia", "Eva", "Fanni", "Geneve", "Geri", "Gladis", "Grayce", "Hannia", "Hellen", "Helene", "Hettie", "Hestor", "Hope", "Hortence", "Isabell", "Isabelea", "Jayne", "Jennie", "Jessamine", "Judeth", "Julya", "Julieta", "Katerine", "Kate", "Lara", "Lea", "Lenora", "Letitea", "Lila", "Lili", "Lilly", "Loreyna", "Lorrayne", "Lottie", "Lucy", "Lulu", "Lydea", "Malda", "Mara", "Mari", "Marthia", "Matelda", "Mattie", "Maude", "Maxine", "Maxie", "Molli", "Mertle", "Nanci", "Nellie", "Nelly", "Nettie", "Nora", "Patsie", "Peggy", "Phoebe", "Polli", "Rachel", "Rebeka", "Rhoda", "Rowena", "Rufina", "Ruth", "Samantha", "Salli", "Sera", "Savana", "Selina", "Stella", "Ginny", "Vivi", "Winnifred", "Winnie", "Zona"
}

local tExileLastName_1 = { "Red", "Bright", "Golden", "Stone", "Black", "Star", "Far", "Cloud", "Sun", "Vest", "Sun", "Wash", "Star", "Wind", "Blue", "Green", "White", "Orange", "Gray", "Cliff", "Berm", "Mound", "Lake", "Pond", "Harbor", "Ash", "Hall", "Ford", "Reed", "Cross", "Moss", "Plain", "Mist", "Clear", "Grace", "Long", "Wild", "Brave", "Fair", "Good", "Hollow", "Whisper", "Rain", "Breeze", "Bay", "Beach", "Med", "Coast", "Church", "Cotton", "Couch", "Court", "Creek", "Dream", "Dust", "Ferry", "Frost", "Fur", "Garden", "Gate", "Gold", "Grass", "Heart", "Hook", "Horn", "Iron", "Kettle", "Light", "Lily", "Lock", "Look", "Mirror", "Moon", "Ocean", "Mountain", "Oak", "Spruce", "Birch", "Heath", "Beech", "Laurel", "Hazel", "Bass", "Willow", "Palm", "Rose", "Saw", "Sea", "Steel", "Summer", "Autumn", "Spring", "Winter", "Sword", "Wind", "Witch"
}

local tExileLastName_2 = { "land", "field", "stone", "walk", "wood", "ward", "strom", "word", "ward", "down", "hand", "kill", "break", "rand", "fall", "town", "ton", "sen", "ston", "smith", "er", "tan", "fell", "dock", "storm", "run", "hall", "wood", "hill", "moore", "lee", "shaw", "ford", "west", "ham", "marsh", "lane", "moss", "heath", "head", "ly", "send", "den", "thorpe", "taker", "shaw", "wick", "cliffe", "lor", "jorst", "hurst", "bury", "park", "by", "creek", "garden", "berry", "hedge", "side", "grove", "vale"
}

local tGranokName_1 = { "Bro", "Bre", "Gro", "Pano", "Pra", "Zano", "Dro", "Tro", "Tra", "Ra", "Ro", "Re", "Ru", "Bru", "Bra", "Dru", "Gra", "Gre", "Ja", "Jo", "Je", "Kra", "Kro", "Kre", "Kru", "La", "Le", "Lo", "Ma", "Mo", "Me", "Vo", "Va", "Ve", "Ga", "Gu", "Go", "Ka", "Ke", "Ko", "Ku", "De", "Da" 
}

local tGranokNameMale_2 = { "g", "gar", "gaz", "gez", "gor", "k", "kag", "keg", "ko", "kog", "rax", "rox", "taz", "toz", "xag", "xan", "xen", "xo", "xog", "z", "ko", "ggar", "ggor", "kke"
}

local tGranokNameFemale_2 = { "aga", "uga", "oga", "oxa", "axa", "oka", "aka", "ara", "all", "alla", "olla", "ella", "agu", "ugu", "ogu", "oxu", "axu", "oku", "aku", "aru", "allu", "ollu"
}

local tGranokLastName_1 = {"Crunch", "Crush", "Gravel", "Gun", "Hell", "Jag", "Onyx", "Sand", "Shield", "Shot", "Siege", "Slag", "Slam", "Stomp", "Storm", "Thunder"
}

local tGranokLastName_2 = {"hammer", "hunter", "maker", "rock", "runner", "shaker", "slugger", "smasher", "stone", "striker", "thrasher", "thumper", "wrecker"
}

local tAurinFirstName_1 = { "Ash", "Br", "Ch", "Chi", "Fan", "Fen", "For", "Jar", "Kai", "Lyr", "Mel", "My", "Per", "Shea", "Sta", "Thu", "Val", "Val", "Var", "Ven", "Yal", "Zyn"
}

local tAurinFirstNameMale_2 = { "all", "an", "ann", "ash", "ath", "eann", "ell", "enn", "es", "esh", "ess", "ian", "ill", "oll", "om", "osh", "oth", "rell", "ress", "yan", "yar", "ymm", "ynn", "yshi", "ythii", "ym", "ynn", "ysh", "yth"
}

local tAurinFirstNameFemale_2 = { "ala", "alla", "anna", "anna", "ashi", "atha", "eanni", "ella", "enna", "iana", "lla", "lli", "oma", "osha", "oshi", "otha", "othi", "ra", "ri", "ya", "yanna"
}

local tAurinLastName_1 = { "Beryl", "Broken", "Dew", "Ever", "Field", "Gale", "Gentle", "Gold", "Gray", "Green", "Long", "Meadow", "Mirth", "Moon", "Moss", "Needle", "Red", "Sage", "Shy", "Silver", "Sky", "Small", "Soul", "Stem", "Star", "Sun", "Sweet", "Thorn", "Tru", "Violet", "Wander", "Water", "Whisper", "White", "Wild", "Wind", "Cerulean"
}

local tAurinLastName_2 = { "bark", "branch", "breeze", "brush", "bud", "bur", "clear", "clover", "drop", "ear", "fall", "fell", "fern", "flower", "gale", "glade", "grass", "grove", "leaf", "root", "seed", "song", "soul", "spring", "sprout", "star", "stem", "tail", "thistle", "thorn", "tree", "vale", "walk", "weave", "weed", "wind", "wood"
}

local tMordeshFirstNameMale = { "Alexander", "Alexi", "Alexis", "Bedrich", "Cenek", "Dominik", "Dusan", "Edvard", "Elias", "Georg", "Havel", "Imrich", "Ivan", "Jakub", "Josef", "Kamil", "Konstantin", "Krystof", "Leos", "Ludvik", "Lukas", "Marek", "Matus", "Milos", "Mirek", "Nikola", "Oldrich", "Otokar", "Pavel", "Paval", "Petr", "Radek", "Reostislav", "Simon", "Stefan", "Tibor", "Tomas", "Vilem", "Vladimir", "Vlasta", "Zdenek", "Zdenko", "Afanas", "Aleks", "Anton", "Alexi", "Boris", "Dima", "Dmitri", "Grigory", "Igor", "Isidor", "Jaska", "Kolzak", "Lazar", "Ludmil", "Mikhail", "Miron", "Oleg", "Osip", "Pasha", "Pyotr", "Timur", "Stas", "Vadim", "Vlad", "Yegor", "Zakhar"
}
local tMordeshFirstNameFemale = { "Adela", "Adriena", "Ana", "Ancika", "Andela", "Bara", "Bohdana", "Bora", "Dagmar", "Dusa", "Dusanka", "Eliska", "Hedvika", "Irena", "Iva", "Ivana", "Izabella", "Jarmilla", "Josefa", "Judita", "Karina", "Katarina", "Katica", "Kveta", "Lenka", "Leona", "Libuse", "Lucina", "Madlenka", "Marketa", "Matylda", "Milada", "Miloslava", "Nadezda", "Pavla", "Radka", "Sobeska", "Svetla", "Svetlana", "Tatana", "Ursula", "Vendula", "Zdenka", "Zuzana", "Agnessa", "Agnesse", "Anastasia", "Esfir", "Inna", "Grusha", "Kata", "Katenka", "Katja", "Naida", "Nika", "Rada", "Tamra", "Varinka", "Yelena", "Yeva", "Yulia", "Yuliana", "Zhanna", "Zhenya", "Zoya", "Katsa"
}

local tMordeshLastName_1 = { "Vikto", "Borg", "Piot", "Yur", "Laz", "Khol", "Greg", "Inga", "Sha", "Vos", "Anga", "Ari", "Gris", "Kev", "Esm", "Yak", "Ver", "Pap", "Brek", "Kasp", "Kaspar", "Kat", "Kond", "Koss", "Vol", "Pud", "Pudo", "Zar", "Zark", "Zhar", "Petr", "Vla"
}

local tMordeshLastName_2 = { "arin", "irin", "ov", "off", "ian", "ijan", "ich", "ich", "vic", "tor", "esh", "osh", "ash", "oli", "ilo", "mara", "ikan", "ova", "chev", "ovich", "vich", "sky", "nev", "rev", "zov", "kin", "venko", "lo", "ko", "lov", "sak", "vak", "kovian", "owski", "ukov", "ikov", "ovkin", "nov", "bek", "os", "in"
}

local tDrakenName_1 = {"Aki", "Dra", "Dre", "Ja", "Kla", "Kol", "Kor", "Za", "De", "Ke", "Le", "La", "Ve"
}

local tDrakenNameMale_2 = {"gh", "kaar", "kar", "kros", "los", "rak", "razz", "rik", "ros", "vok", "za", "zar", "zad", "zka", "zaar", "zrek", "zrak"
}

local tDrakenNameFemale_2 = {"zia", "za", "ka", "kia", "zzia", "tia", "dia", "ra", "da", "kra", "zza", "kkia", "kka", "la", "lia", "nia", "mia", "na", "sa", "va", "via", "ari", "ari", "ari"
}

local tDraken_LastName_1 = {"Doom", "Edge", "Gore", "Gut", "Havoc", "Hell", "Murder", "Night", "Razor", "Red", "Ruin", "Savage", "Shadow", "Slash", "Spine", "Stalk", "Terror", "Wrath"
}

local tDraken_LastName_2 = {"horn", "hunter", "kill", "kind", "lash", "lord", "maker", "marked", "master", "render", "ripper", "scaler", "slayer", "storm", "strike", "sworn", "taken", "torn"
}

local tChuaFirstName_1 = { "Ab", "Al", "Am", "An", "Bad", "Bag", "Bal", "Ban", "Baz", "Baz", "Ben", "Ber", "Bez", "Big", "Bin", "Biz", "Bog", "Bon", "Bor", "Boz", "Bun", "Dur", "Eg", "Fan", "Fen", "Fin", "Fin", "Fon", "Fon", "Fos", "Fram", "Fraz", "Frez", "Friz", "Froz", "Frum", "Fruz", "Gar", "Gaz", "Ger", "Gez", "Gin", "Gir", "Giz", "Graz", "Grez", "Gril", "Grim", "Grin", "Griz", "Grom", "Groz", "Gruz", "Gun", "Jar", "Jir", "Jur", "Kad", "Kar", "Or", "Saz", "Sen", "Sez", "Siz", "Soz", "Suz", "Tan", "Zar", "Zer", "Zert", "Zor", "Fuz", "B", "D", "F", "G", "H", "J", "K", "L", "M", "P", "R", "S", "T", "V", "W", "Z"
}

local tChuaFirstName_2 = { "am", "ami", "ango", "ani", "ani", "ati", "az", "az", "azi", "azi", "azz", "emi", "enni", "enzi", "enzo", "er", "im", "imp", "ingo", "oingo", "ongo", "ont", "onti", "um", "ump", "ungo"
}

local tChuaLastName_1 = { "B", "D", "F", "G", "H", "J", "K", "L", "M", "P", "R", "S", "T", "V", "W", "Z"
}

local tChuaLastName_2 = { "ai", "ang", "anti", "ax", "azz", "el", "eng", "enti", "ento", "ezz", "il", "ing", "inti", "ong", "onti", "ozz", "ral", "razz", "rel", "rezz", "ric", "ril", "rizz", "roc", "rol", "rozz", "ruc", "rum", "uc", "ui", "um", "un", "uo"
}

local tMechariName_1 = { "A", "Ac", "Acr", "Ad", "Al", "Amph", "Ar", "Arc", "Arch", "Con", "Cry", "Cyb", "Dat", "Dem", "Ex", "Gig", "Hy", "Hyd", "Hydr", "Id", "In", "Lev", "Log", "Lor", "Ly", "Lyt", "Magn", "Mec", "Mem", "Mor", "Neur", "Nor", "Ny", "Pen", "Per", "Ser", "Tir", "Tor", "Tra", "Typ", "Tyr", "Umbr", "Var", "Vec", "Ver", "Vid", "Vir", "Vol", "Vy", "Vyt", "Zyr"
}

local tMechariNameMale_2 = {"ac", "ax", "eic", "ept", "ex", "ic", "in", "io", "iom", "ion", "ix", "o", "oc", "ose", "ox", "um", "uon", "ux", "is"
}

local tMechariNameFemale_2 = { "a", "eica", "ena", "ene", "exa", "ia", "ie", "ina", "inia", "itie", "osia", "umia", "ydra"
}

local tMechariLastName_1 = {"Alpha", "Beta", "Centi", "Deca", "Deci", "Deco", "Delta", "Dua", "Duo", "Duode", "Gamma", "Giga", "Hexa", "Kilo", "Macro", "Meta", "Micro", "Milli", "Mono", "Nova", "Novi", "Novo", "Octa", "Octi", "Octo", "Omega", "Omni", "Quadra", "Quadri", "Quadro", "Quinta", "Quinti", "Quinto", "Secta", "Secti", "Secto", "Septa", "Septi", "Septo", "Sigma", "Tau", "Tera", "Theta", "Tria", "Trio", "Ulti", "Ultra", "Una", "Uni", "Uno", "Zeta"
}

local tMechariLastName_2 = {"bolt", "cell", "con", "core", "cron", "cus", "lux", "mac", "max", "mec", "mox", "nex", "niex", "nion", "nix", "noc", "noid", "nox", "pax", "phax", "phex", "phix", "plex", "rax", "rem", "rex", "rion", "rix", "rom", "rox", "spark", "tec", "tec", "tech", "triax", "trion", "troid", "tron", "vac", "vec", "vex", "viex", "vion", "volt", "vox", "xen", "xine", "xon", "zec", "zoid", "zox"
}

local tCassianFirstNameMale = { "Aelius", "Aelianus", "Emil", "Emiliano", "Aetius", "Albus", "Atilius", "Aulus", "Avictus", "Blasius", "Balbinus", "Caecilius", "Caelius", "Caius", "Cato", "Celsus", "Cornelius", "Crispin", "Decimus", "Domitus", "Drusus", "Dulio", "Egnatius", "Fabius", "Flavius", "Florian", "Gallus", "Glaucian", "Herminius", "Julius", "Lucius", "Lucianus", "Lucrius", "Marcellus", "Marcius", "Otho", "Ovidius", "Petronius", "Pomponius", "Quintus", "Regulus", "Rufinus", "Sabinus", "Severus", "Tacitus", "Tatius", "Tullius", "Varinius", "Vitus", "Anton", "Antonus", "Anonius", "Avitus"
}

local tCassianFirstNameFemale = { "Aelia", "Aeliana", "Aemilia", "Aemiliana", "Aetia", "Alba", "Atilia", "Aulia", "Avicta", "Blasia", "Balbina", "Cecilia", "Caelia", "Caia", "Catia", "Celia", "Cornelia", "Crispa", "Decima", "Domita", "Drusa", "Dulia", "Egnatia", "Fabia", "Flavia", "Floriana", "Gallia", "Glaucia", "Herminia", "Julia", "Lucia", "Luciana", "Lucretia", "Marcella", "Marcia", "Othia", "Ovidia", "Petronia", "Pomponia", "Quintina", "Regula", "Rufina", "Sabina", "Severina", "Tacitus", "Tatiana", "Tullia", "Varinia", "Vita", "Antonia"
}

local tCassianLastName_1 = { "Air", "Al", "Alc", "Alm", "Amaran", "Anatol", "Aquil", "Athan", "Atil", "Aur", "Aurel", "Avit", "Bel", "Beth", "Cam", "Crisp", "Cur", "Cy", "Cyr", "Dan", "Dec", "Dev", "Dom", "Flav", "Flev", "Fliv", "Flov", "Fluv", "Har", "Her", "Hir", "Hor", "Hor", "Horten", "Hur", "Jan", "Jin", "Jov", "Jur", "Jur", "Lav", "Liv", "Luc", "Mal", "Malc", "Mar", "Marc", "Max", "Mox", "Ner", "Nom", "Nox", "Pall", "Parr", "Pat", "Patr", "Pet", "Petr", "Plin", "Py", "Pyr", "Regul", "Sab", "Sabin", "Sal", "Sev", "Sever", "Siv", "Tiber", "Tit", "Tor", "Tul", "Val", "Var", "Ver", "Vic", "Voc", "Aelm", "Ael"
}

local tCassianLastName_2 = { "ec", "os", "es", "eus", "ius", "ios", "is", "us", "ex"
}

function RandomNameGenerator(nRaceId, nFactionId, nGenderId)

	if nRaceId == 1 then -- Cassian or Human
		if nFactionId == 167 then
			if nGenderId == 0 then
				tFirstName = tExileFirstNameMale[math.random(1, #tExileFirstNameMale)]
			else
				tFirstName = tExileFirstNameFemale[math.random(1, #tExileFirstNameFemale)]
			end
			
			local strExileLastName1 = tExileLastName_1[math.random(1, #tExileLastName_1)]
			local strExileLastName2 = tExileLastName_2[math.random(1, #tExileLastName_2)]
			tLastName = strExileLastName1 .. strExileLastName2
		else 
			if nGenderId == 0 then
				tFirstName = tCassianFirstNameMale[math.random(1, #tCassianFirstNameMale)]
			else
				tFirstName = tCassianFirstNameFemale[math.random(1, #tCassianFirstNameFemale)]
			end
			
			local strCassianLastName1 = tCassianLastName_1[math.random(1, #tCassianLastName_1)]
			local strCassianLastName2 = tCassianLastName_2[math.random(1, #tCassianLastName_2)]
			tLastName = strCassianLastName1 .. strCassianLastName2
		end
		
	elseif nRaceId == 4 then -- Aurin
			local strAurinFirstName1 = tAurinFirstName_1[math.random(1, #tAurinFirstName_1)]
			if nGenderId == 0 then
				local strAurinFirstName2 = tAurinFirstNameMale_2[math.random(1, #tAurinFirstNameMale_2)]
				tFirstName = strAurinFirstName1 .. strAurinFirstName2
			else
				local strAurinFirstName2 = tAurinFirstNameFemale_2[math.random(1, #tAurinFirstNameFemale_2)]
				tFirstName = strAurinFirstName1 .. strAurinFirstName2
			end
			
			local strAurinLastName1 = tAurinLastName_1[math.random(1, #tAurinLastName_1)]
			local strAurinLastName2 = tAurinLastName_2[math.random(1, #tAurinLastName_2)]
			tLastName = strAurinLastName1 .. strAurinLastName2
			
	elseif nRaceId == 3 then -- Granok
		local strGranokName1 = tGranokName_1[math.random(1, #tGranokName_1)]

		if nGenderId == 0 then
			local strGranokLastMale2 = tGranokNameMale_2[math.random(1, #tGranokNameMale_2)]
			local strGranokFirstMale2 = tGranokNameMale_2[math.random(1, #tGranokNameMale_2)]
			tFirstName = strGranokName1 .. strGranokFirstMale2 
		else
			local strGranokFirstFemale2 = tGranokNameFemale_2[math.random(1, #tGranokNameFemale_2)]
			local strGranokLastFemale2 = tGranokNameFemale_2[math.random(1, #tGranokNameFemale_2)]
			tFirstName = strGranokName1 .. strGranokFirstFemale2 
		end
		local strGranokLastName1 = tGranokLastName_1[math.random(1, #tGranokLastName_1)]
		local strGranokLastName2 = tGranokLastName_2[math.random(1, #tGranokLastName_2)]
		tLastName = strGranokLastName1 .. strGranokLastName2 

	elseif nRaceId == 16 then -- Mordesh
		if nGenderId == 0 then
			tFirstName = tMordeshFirstNameMale[math.random(1, #tMordeshFirstNameMale)]
		else
			tFirstName = tMordeshFirstNameFemale[math.random(1, #tMordeshFirstNameFemale)]
		end
		
		local strMordeshLastName1 = tMordeshLastName_1[math.random(1, #tMordeshLastName_1)]
		local strMordeshLastName2 = tMordeshLastName_2[math.random(1, #tMordeshLastName_2)]
		tLastName = strMordeshLastName1 .. strMordeshLastName2
		
	elseif nRaceId == 5 then -- Draken
		local strDrakenName1 = tDrakenName_1[math.random(1, #tDrakenName_1)]
		if nGenderId == 0 then
			local strDrakenFirstMale2 = tDrakenNameMale_2[math.random(1, #tDrakenNameMale_2)]
			tFirstName = strDrakenName1 .. strDrakenFirstMale2 
		else
			local strDrakenFirstFemale2 = tDrakenNameFemale_2[math.random(1, #tDrakenNameFemale_2)]
			tFirstName = strDrakenName1 .. strDrakenFirstFemale2 
		end
		local strDrakenLastName1 = tDraken_LastName_1[math.random(1, #tDraken_LastName_1)]
		local strDrakenLastName2 = tDraken_LastName_2[math.random(1, #tDraken_LastName_2)]
		tLastName = strDrakenLastName1 .. strDrakenLastName2 
	
	elseif nRaceId == 13 then -- Chua
		local strChuaFirstName1 = tChuaFirstName_1[math.random(1, #tChuaFirstName_1)]
		local strChuaFirstName2 = tChuaFirstName_2[math.random(1, #tChuaFirstName_2)]
		tFirstName = strChuaFirstName1 .. strChuaFirstName2
		
		local strChuaLastName1 = tChuaLastName_1[math.random(1, #tChuaLastName_1)]
		local strChuaLastName2 = tChuaLastName_2[math.random(1, #tChuaLastName_2)]
		tLastName = strChuaLastName1 .. strChuaLastName2 
		
	elseif nRaceId == 12 then -- Mechari
		local strMechariName1 = tMechariName_1[math.random(1, #tMechariName_1)]
		if nGenderId == 0 then
			local strMechariFirstMale2 = tMechariNameMale_2[math.random(1, #tMechariNameMale_2)]
			tFirstName = strMechariName1 .. strMechariFirstMale2 
		else
			local strMechariFirstFemale2 = tMechariNameFemale_2[math.random(1, #tMechariNameFemale_2)]
			tFirstName = strMechariName1 .. strMechariFirstFemale2 
		end
		local strMechariLastName1 = tMechariLastName_1[math.random(1, #tMechariLastName_1)]
		local strMechariLastName2 = tMechariLastName_2[math.random(1, #tMechariLastName_2)]
		tLastName = strMechariLastName1 .. strMechariLastName2 

	end

	return tLastName, tFirstName
end
local CharacterNamesInst = CharacterNames:new()
CharacterNames:Init()
