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

local ktCharacterNames =
{
	[PreGameLib.CodeEnumFaction.Exile] =
	{
		[PreGameLib.CodeEnumRace.Human] =
		{
			[PreGameLib.CodeEnumGender.Male] = {"Aron", "Abram", "Abe", "Alan", "Allen", "Albert", "Alonzo", "Ambrose", "Amon", "Amos", "Andie", "Arch", "Asa", "Barnabas", "Barney", "Bart", "Ben", "Bennet", "Bern", "Bertrom", "Bertal", "Byford", "Byrone", "Calven", "Cris", "Clem", "Clent", "Clynt", "Cole", "Perrie", "Dan", "Davon", "Davan", "Devan", "Devyn", "Edmund", "Edward", "Edwin", "Eldon", "Eli", "Enett", "Emmett", "Enoch", "Ezekiel", "Ezra", "Gabe", "Garrett", "Jorge", "Gideon", "Gilvert", "Gil", "Gus", "Harland", "Harison", "Harolt", "Hiran", "Hiram", "Izaac", "Jakeb", "Jake", "Jaymes", "Jazper", "Jeck", "Jed", "Jeb", "Jep", "Jesse", "Jole", "Jon", "Leander", "Les", "Lowis", "Levi", "Lucas", "Luke", "Luther", "Mathis", "Mark", "Martyn", "Maxwell", "Merrill", "Meriwether", "Mike", "Micah", "Morgan", "Moris", "Nathon", "Nate", "Nat", "Ned", "Newton", "Nick", "Obediah", "Orvil", "Oscor", "Owen", "Ralf", "Ray", "Rubin", "Roebert", "Ritch", "Rufis", "Rufos", "Samel", "Sam", "Seth", "Silas", "Simon", "Stan", "Stephen", "Thad", "Thadd", "Thom", "Tomis", "Tom", "Theo", "Ted", "Timothi", "Tim", "Victer", "Waltor", "Waren", "Will", "Willie", "Zebulon", "Zedock", "Zeke",},
			[PreGameLib.CodeEnumGender.Female] = {"Abigale", "Abby", "Ada", "Adella", "Allie", "Almyra", "Alva", "Amela", "Ayn", "An", "Ann", "Arrah", "Becki", "Bess", "Bessie", "Charlot", "Clayre", "Cynthea", "Dorothea", "Dot", "Edyth", "Edwina", "Ella", "Elayne", "Ellie", "Elyza", "Lyza", "Liza", "Lizi", "Ema", "Etty", "Evia", "Eva", "Fanni", "Geneve", "Geri", "Gladis", "Grayce", "Hannia", "Hellen", "Helene", "Hettie", "Hestor", "Hope", "Hortence", "Isabell", "Isabelea", "Jayne", "Jennie", "Jessamine", "Judeth", "Julya", "Julieta", "Katerine", "Kate", "Lara", "Lea", "Lenora", "Letitea", "Lila", "Lili", "Lilly", "Loreyna", "Lorrayne", "Lottie", "Lucy", "Lulu", "Lydea", "Malda", "Mara", "Mari", "Marthia", "Matelda", "Mattie", "Maude", "Maxine", "Maxie", "Molli", "Mertle", "Nanci", "Nellie", "Nelly", "Nettie", "Nora", "Patsie", "Peggy", "Phoebe", "Polli", "Rachel", "Rebeka", "Rhoda", "Rowena", "Rufina", "Ruth", "Samantha", "Salli", "Sera", "Savana", "Selina", "Stella", "Ginny", "Vivi", "Winnifred", "Winnie", "Zona",},
			arLastNamePrefix = {"Red", "Bright", "Golden", "Stone", "Black", "Star", "Far", "Cloud", "Sun", "Vest", "Sun", "Wash", "Star", "Wind", "Blue", "Green", "White", "Orange", "Gray", "Cliff", "Berm", "Mound", "Lake", "Pond", "Harbor", "Ash", "Hall", "Ford", "Reed", "Cross", "Moss", "Plain", "Mist", "Clear", "Grace", "Long", "Wild", "Brave", "Fair", "Good", "Hollow", "Whisper", "Rain", "Breeze", "Bay", "Beach", "Med", "Coast", "Church", "Cotton", "Couch", "Court", "Creek", "Dream", "Dust", "Ferry", "Frost", "Fur", "Garden", "Gate", "Gold", "Grass", "Heart", "Hook", "Horn", "Iron", "Kettle", "Light", "Lily", "Lock", "Look", "Mirror", "Moon", "Ocean", "Mountain", "Oak", "Spruce", "Birch", "Heath", "Beech", "Laurel", "Hazel", "Bass", "Willow", "Palm", "Rose", "Saw", "Sea", "Steel", "Summer", "Autumn", "Spring", "Winter", "Sword", "Wind", "Witch",},
			arLastNameSuffix = {"land", "field", "stone", "walk", "wood", "ward", "strom", "word", "ward", "down", "hand", "kill", "break", "rand", "fall", "town", "ton", "sen", "ston", "smith", "er", "tan", "fell", "dock", "storm", "run", "hall", "wood", "hill", "moore", "lee", "shaw", "ford", "west", "ham", "marsh", "lane", "moss", "heath", "head", "ly", "send", "den", "thorpe", "taker", "shaw", "wick", "cliffe", "lor", "jorst", "hurst", "bury", "park", "by", "creek", "garden", "berry", "hedge", "side", "grove", "vale",},
		},
		
		[PreGameLib.CodeEnumRace.Granok] = 
		{
			arFirstNamePrefix = {"Bro", "Bre", "Gro", "Pano", "Pra", "Zano", "Dro", "Tro", "Tra", "Ra", "Ro", "Re", "Ru", "Bru", "Bra", "Dru", "Gra", "Gre", "Ja", "Jo", "Je", "Kra", "Kro", "Kre", "Kru", "La", "Le", "Lo", "Ma", "Mo", "Me", "Vo", "Va", "Ve", "Ga", "Gu", "Go", "Ka", "Ke", "Ko", "Ku", "De", "Da",},
			[PreGameLib.CodeEnumGender.Male] = {"g", "gar", "gaz", "gez", "gor", "k", "kag", "keg", "ko", "kog", "rax", "rox", "taz", "toz", "xag", "xan", "xen", "xo", "xog", "z", "ko", "ggar", "ggor", "kke",},
			[PreGameLib.CodeEnumGender.Female] = {"aga", "uga", "oga", "oxa", "axa", "oka", "aka", "ara", "all", "alla", "olla", "ella", "agu", "ugu", "ogu", "oxu", "axu", "oku", "aku", "aru", "allu", "ollu",},
			arLastNamePrefix = {"Crunch", "Crush", "Gravel", "Gun", "Hell", "Jag", "Onyx", "Sand", "Shield", "Shot", "Siege", "Slag", "Slam", "Stomp", "Storm", "Thunder",},
			arLastNameSuffix = {"hammer", "hunter", "maker", "rock", "runner", "shaker", "slugger", "smasher", "stone", "striker", "thrasher", "thumper", "wrecker",},
		},
		
		[PreGameLib.CodeEnumRace.Aurin] = 
		{
			arFirstNamePrefix = {"Ash", "Br", "Ch", "Chi", "Fan", "Fen", "For", "Jar", "Kai", "Lyr", "Mel", "My", "Per", "Shea", "Sta", "Thu", "Val", "Val", "Var", "Ven", "Yal", "Zyn",},
			[PreGameLib.CodeEnumGender.Male] = {"all", "an", "ann", "ash", "ath", "eann", "ell", "enn", "es", "esh", "ess", "ian", "ill", "oll", "om", "osh", "oth", "rell", "ress", "yan", "yar", "ymm", "ynn", "yshi", "ythii", "ym", "ynn", "ysh", "yth",},
			[PreGameLib.CodeEnumGender.Female] = {"ala", "alla", "anna", "anna", "ashi", "atha", "eanni", "ella", "enna", "iana", "lla", "lli", "oma", "osha", "oshi", "otha", "othi", "ra", "ri", "ya", "yanna",},
			arLastNamePrefix = {"Beryl", "Broken", "Dew", "Ever", "Field", "Gale", "Gentle", "Gold", "Gray", "Green", "Long", "Meadow", "Mirth", "Moon", "Moss", "Needle", "Red", "Sage", "Shy", "Silver", "Sky", "Small", "Soul", "Stem", "Star", "Sun", "Sweet", "Thorn", "Tru", "Violet", "Wander", "Water", "Whisper", "White", "Wild", "Wind", "Cerulean",},
			arLastNameSuffix = {"bark", "branch", "breeze", "brush", "bud", "bur", "clear", "clover", "drop", "ear", "fall", "fell", "fern", "flower", "gale", "glade", "grass", "grove", "leaf", "root", "seed", "song", "soul", "spring", "sprout", "star", "stem", "tail", "thistle", "thorn", "tree", "vale", "walk", "weave", "weed", "wind", "wood",},
		},
		
		[PreGameLib.CodeEnumRace.Mordesh] =
		{
			[PreGameLib.CodeEnumGender.Male] = {"Alexander", "Alexi", "Alexis", "Bedrich", "Cenek", "Dominik", "Dusan", "Edvard", "Elias", "Georg", "Havel", "Imrich", "Ivan", "Jakub", "Josef", "Kamil", "Konstantin", "Krystof", "Leos", "Ludvik", "Lukas", "Marek", "Matus", "Milos", "Mirek", "Nikola", "Oldrich", "Otokar", "Pavel", "Paval", "Petr", "Radek", "Reostislav", "Simon", "Stefan", "Tibor", "Tomas", "Vilem", "Vladimir", "Vlasta", "Zdenek", "Zdenko", "Afanas", "Aleks", "Anton", "Alexi", "Boris", "Dima", "Dmitri", "Grigory", "Igor", "Isidor", "Jaska", "Kolzak", "Lazar", "Ludmil", "Mikhail", "Miron", "Oleg", "Osip", "Pasha", "Pyotr", "Timur", "Stas", "Vadim", "Vlad", "Yegor", "Zakhar",},
			[PreGameLib.CodeEnumGender.Female] = {"Adela", "Adriena", "Ana", "Ancika", "Andela", "Bara", "Bohdana", "Bora", "Dagmar", "Dusa", "Dusanka", "Eliska", "Hedvika", "Irena", "Iva", "Ivana", "Izabella", "Jarmilla", "Josefa", "Judita", "Karina", "Katarina", "Katica", "Kveta", "Lenka", "Leona", "Libuse", "Lucina", "Madlenka", "Marketa", "Matylda", "Milada", "Miloslava", "Nadezda", "Pavla", "Radka", "Sobeska", "Svetla", "Svetlana", "Tatana", "Ursula", "Vendula", "Zdenka", "Zuzana", "Agnessa", "Agnesse", "Anastasia", "Esfir", "Inna", "Grusha", "Kata", "Katenka", "Katja", "Naida", "Nika", "Rada", "Tamra", "Varinka", "Yelena", "Yeva", "Yulia", "Yuliana", "Zhanna", "Zhenya", "Zoya", "Katsa",},
			arLastNamePrefix = {"Vikto", "Borg", "Piot", "Yur", "Laz", "Khol", "Greg", "Inga", "Sha", "Vos", "Anga", "Ari", "Gris", "Kev", "Esm", "Yak", "Ver", "Pap", "Brek", "Kasp", "Kaspar", "Kat", "Kond", "Koss", "Vol", "Pud", "Pudo", "Zar", "Zark", "Zhar", "Petr", "Vla",},
			arLastNameSuffix = {"arin", "irin", "ov", "off", "ian", "ijan", "ich", "ich", "vic", "tor", "esh", "osh", "ash", "oli", "ilo", "mara", "ikan", "ova", "chev", "ovich", "vich", "sky", "nev", "rev", "zov", "kin", "venko", "lo", "ko", "lov", "sak", "vak", "kovian", "owski", "ukov", "ikov", "ovkin", "nov", "bek", "os", "in",},
		},
	},
	
	[PreGameLib.CodeEnumFaction.Dominion] =
	{
		[PreGameLib.CodeEnumRace.Human] =
		{
			[PreGameLib.CodeEnumGender.Male] = {"Aelius", "Aelianus", "Emil", "Emiliano", "Aetius", "Albus", "Atilius", "Aulus", "Avictus", "Blasius", "Balbinus", "Caecilius", "Caelius", "Caius", "Cato", "Celsus", "Cornelius", "Crispin", "Decimus", "Domitus", "Drusus", "Dulio", "Egnatius", "Fabius", "Flavius", "Florian", "Gallus", "Glaucian", "Herminius", "Julius", "Lucius", "Lucianus", "Lucrius", "Marcellus", "Marcius", "Otho", "Ovidius", "Petronius", "Pomponius", "Quintus", "Regulus", "Rufinus", "Sabinus", "Severus", "Tacitus", "Tatius", "Tullius", "Varinius", "Vitus", "Anton", "Antonus", "Anonius", "Avitus",},
			[PreGameLib.CodeEnumGender.Female] = {"Aelia", "Aeliana", "Aemilia", "Aemiliana", "Aetia", "Alba", "Atilia", "Aulia", "Avicta", "Blasia", "Balbina", "Cecilia", "Caelia", "Caia", "Catia", "Celia", "Cornelia", "Crispa", "Decima", "Domita", "Drusa", "Dulia", "Egnatia", "Fabia", "Flavia", "Floriana", "Gallia", "Glaucia", "Herminia", "Julia", "Lucia", "Luciana", "Lucretia", "Marcella", "Marcia", "Othia", "Ovidia", "Petronia", "Pomponia", "Quintina", "Regula", "Rufina", "Sabina", "Severina", "Tacitus", "Tatiana", "Tullia", "Varinia", "Vita", "Antonia",},
			arLastNamePrefix = {"Air", "Al", "Alc", "Alm", "Amaran", "Anatol", "Aquil", "Athan", "Atil", "Aur", "Aurel", "Avit", "Bel", "Beth", "Cam", "Crisp", "Cur", "Cy", "Cyr", "Dan", "Dec", "Dev", "Dom", "Flav", "Flev", "Fliv", "Flov", "Fluv", "Har", "Her", "Hir", "Hor", "Hor", "Horten", "Hur", "Jan", "Jin", "Jov", "Jur", "Jur", "Lav", "Liv", "Luc", "Mal", "Malc", "Mar", "Marc", "Max", "Mox", "Ner", "Nom", "Nox", "Pall", "Parr", "Pat", "Patr", "Pet", "Petr", "Plin", "Py", "Pyr", "Regul", "Sab", "Sabin", "Sal", "Sev", "Sever", "Siv", "Tiber", "Tit", "Tor", "Tul", "Val", "Var", "Ver", "Vic", "Voc", "Aelm", "Ael",},
			arLastNameSuffix = {"ec", "os", "es", "eus", "ius", "ios", "is", "us", "ex",},
		},
		
		[PreGameLib.CodeEnumRace.Draken] =
		{
			arFirstNamePrefix = {"Aki", "Dra", "Dre", "Ja", "Kla", "Kol", "Kor", "Za", "De", "Ke", "Le", "La", "Ve"},
			[PreGameLib.CodeEnumGender.Male] = {"gh", "kaar", "kar", "kros", "los", "rak", "razz", "rik", "ros", "vok", "za", "zar", "zad", "zka", "zaar", "zrek", "zrak",},
			[PreGameLib.CodeEnumGender.Female] = {"zia", "za", "ka", "kia", "zzia", "tia", "dia", "ra", "da", "kra", "zza", "kkia", "kka", "la", "lia", "nia", "mia", "na", "sa", "va", "via", "ari", "ari", "ari",},
			arLastNamePrefix = {"Doom", "Edge", "Gore", "Gut", "Havoc", "Hell", "Murder", "Night", "Razor", "Red", "Ruin", "Savage", "Shadow", "Slash", "Spine", "Stalk", "Terror", "Wrath",},
			arLastNameSuffix = {"horn", "hunter", "kill", "kind", "lash", "lord", "maker", "marked", "master", "render", "ripper", "scaler", "slayer", "storm", "strike", "sworn", "taken", "torn",},
		},
		
		[PreGameLib.CodeEnumRace.Chua] =
		{
			arFirstNamePrefix = { "Ab", "Al", "Am", "An", "Bad", "Bag", "Bal", "Ban", "Baz", "Baz", "Ben", "Ber", "Bez", "Big", "Bin", "Biz", "Bog", "Bon", "Bor", "Boz", "Bun", "Dur", "Eg", "Fan", "Fen", "Fin", "Fin", "Fon", "Fon", "Fos", "Fram", "Fraz", "Frez", "Friz", "Froz", "Frum", "Fruz", "Gar", "Gaz", "Ger", "Gez", "Gin", "Gir", "Giz", "Graz", "Grez", "Gril", "Grim", "Grin", "Griz", "Grom", "Groz", "Gruz", "Gun", "Jar", "Jir", "Jur", "Kad", "Kar", "Or", "Saz", "Sen", "Sez", "Siz", "Soz", "Suz", "Tan", "Zar", "Zer", "Zert", "Zor", "Fuz", "B", "D", "F", "G", "H", "J", "K", "L", "M", "P", "R", "S", "T", "V", "W", "Z",},
			[PreGameLib.CodeEnumGender.Male] = { "am", "ami", "ango", "ani", "ani", "ati", "az", "az", "azi", "azi", "azz", "emi", "enni", "enzi", "enzo", "er", "im", "imp", "ingo", "oingo", "ongo", "ont", "onti", "um", "ump", "ungo",},
			arLastNamePrefix = {"B", "D", "F", "G", "H", "J", "K", "L", "M", "P", "R", "S", "T", "V", "W", "Z",},
			arLastNameSuffix = {"ai", "ang", "anti", "ax", "azz", "el", "eng", "enti", "ento", "ezz", "il", "ing", "inti", "ong", "onti", "ozz", "ral", "razz", "rel", "rezz", "ric", "ril", "rizz", "roc", "rol", "rozz", "ruc", "rum", "uc", "ui", "um", "un", "uo",},
		},

		[PreGameLib.CodeEnumRace.Mechari] =
		{
			arFirstNamePrefix = {"A", "Ac", "Acr", "Ad", "Al", "Amph", "Ar", "Arc", "Arch", "Con", "Cry", "Cyb", "Dat", "Dem", "Ex", "Gig", "Hy", "Hyd", "Hydr", "Id", "In", "Lev", "Log", "Lor", "Ly", "Lyt", "Magn", "Mec", "Mem", "Mor", "Neur", "Nor", "Ny", "Pen", "Per", "Ser", "Tir", "Tor", "Tra", "Typ", "Tyr", "Umbr", "Var", "Vec", "Ver", "Vid", "Vir", "Vol", "Vy", "Vyt", "Zyr",},
			[PreGameLib.CodeEnumGender.Male] = {"ac", "ax", "eic", "ept", "ex", "ic", "in", "io", "iom", "ion", "ix", "o", "oc", "ose", "ox", "um", "uon", "ux", "is",},
			[PreGameLib.CodeEnumGender.Female] = {"a", "eica", "ena", "ene", "exa", "ia", "ie", "ina", "inia", "itie", "osia", "umia", "ydra",},
			arLastNamePrefix = {"Alpha", "Beta", "Centi", "Deca", "Deci", "Deco", "Delta", "Dua", "Duo", "Duode", "Gamma", "Giga", "Hexa", "Kilo", "Macro", "Meta", "Micro", "Milli", "Mono", "Nova", "Novi", "Novo", "Octa", "Octi", "Octo", "Omega", "Omni", "Quadra", "Quadri", "Quadro", "Quinta", "Quinti", "Quinto", "Secta", "Secti", "Secto", "Septa", "Septi", "Septo", "Sigma", "Tau", "Tera", "Theta", "Tria", "Trio", "Ulti", "Ultra", "Una", "Uni", "Uno", "Zeta",},
			arLastNameSuffix = {"bolt", "cell", "con", "core", "cron", "cus", "lux", "mac", "max", "mec", "mox", "nex", "niex", "nion", "nix", "noc", "noid", "nox", "pax", "phax", "phex", "phix", "plex", "rax", "rem", "rex", "rion", "rix", "rom", "rox", "spark", "tec", "tec", "tech", "triax", "trion", "troid", "tron", "vac", "vec", "vex", "viex", "vion", "volt", "vox", "xen", "xine", "xon", "zec", "zoid", "zox",},
		},
	},
}

function RandomNameGenerator(idRace, idFaction, idGender)	
	local tNameOptions = ktCharacterNames[idFaction][idRace]
	if not tNameOptions then
		return
	end
	
	local tName =
	{
		strFirstName = "",
		strLastName = "",
	}
	
	if tNameOptions.arFirstNamePrefix then
		tName.strFirstName = tNameOptions.arFirstNamePrefix[math.ceil(math.random(#tNameOptions.arFirstNamePrefix))] .. tNameOptions[idGender][math.ceil(math.random(#tNameOptions[idGender]))]
	else
		tName.strFirstName = tNameOptions[idGender][math.ceil(math.random(#tNameOptions[idGender]))]
	end
	
	tName.strLastName = tNameOptions.arLastNamePrefix[math.ceil(math.random(#tNameOptions.arLastNamePrefix))] .. tNameOptions.arLastNameSuffix[math.ceil(math.random(#tNameOptions.arLastNameSuffix))]
	
	return tName
end

local CharacterNamesInst = CharacterNames:new()
CharacterNames:Init()t="1" RAnchorOffset="-44" BAnchorPoint="0" BAnchorOffset="244" RelativeToClient="1" Font="Default" Text="" Template="Holo_ScrollListSmall" TooltipType="OnCursor" Name="SubCategory" BGColor="ffffffff" TextColor="ffffffff" TooltipColor="" CellBGNormalColor="" CellBGSelectedColor="" CellBGNormalFocusColor="" CellBGSelectedFocusColor="" TextNormalColor="" TextSelectedColor="" TextNormalFocusColor="" TextSelectedFocusColor="" Border="1" VScroll="1" UseTemplateBG="1">
            <Event Name="GridSelChange" Function="OnSubcategoryChanged"/>
        </Control>
        <Control Class="EditBox" Name="Description" ReadOnly="0" MultiLine="1" Template="Holo_ScrollList" VScroll="0" LAnchorPoint="0" LAnchorOffset="52" TAnchorPoint="1" TAnchorOffset="-296" RAnchorPoint="1" RAnchorOffset="-54" BAnchorPoint="1" BAnchorOffset="-113" BGColor="ff000000" TextColor="ffffffff" Focus="True" Border="1" UseTemplateBG="1" RelativeToClient="1" TextId="" TooltipColor="" Text="" WantReturn="1" DT_WORDBREAK="1">
            <Event Name="EditBoxReturn" Function="OnOkBtn"/>
            <Event Name="EditBoxChanged" Function="OnDescriptionChanged"/>
        </Control>
        <Control Class="Window" LAnchorPoint="0" LAnchorOffset="0" TAnchorPoint="0" TAnchorOffset="0" RAnchorPoint="1" RAnchorOffset="0" BAnchorPoint="1" BAnchorOffset="0" RelativeToClient="1" Fo