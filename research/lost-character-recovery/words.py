# Hand-written clean word/name lists. Each language gets ~100 base words;
# build_values() turns them into 200 values: 100 bare words and 100 two-word
# phrases, a share of which carry typographic punctuation.

FR = """été café crème brûlée garçon français élève hôpital forêt château naïve Noël cœur œuvre
déjà voilà très après où façade reçu leçon Hélène Zoé Agnès Benoît Joël Gaëlle Françoise Jérôme
Cécile Ève Raphaël Mathéo Chloé Léa Inès Théo Noémie Clément Bérénice Hervé Rémi Aurélie Séverine
Côte d'Azur Montréal Besançon Orléans Nîmes Évian Sète Bézier Angoulême Pézenas
fenêtre île goût août bientôt dîner épée âme bâton hâte tâche sûr mûr
élégant récit réseau référence crêpe pâté soupçon ça aïeul maïs Moïse égoïste
théâtre événement répertoire sécurité société qualité liberté égalité fraternité
naïveté protégé fiancée résumé cliché décor début entrée purée soirée
""".split()

DE = """Größe Straße Mädchen Müller Schäfer Köln München Düsseldorf Zürich Bär Löwe Übung
Fräulein Grüße Käse Brötchen Gemüse Frühstück Glück schön müde hören fühlen Äpfel Öl
Jürgen Jörg Björn Günther Dörte Sören Jürgens Bärbel Käthe Hänsel Gößling Rüdiger Lübeck
Göttingen Nürnberg Würzburg Saarbrücken Lüneburg Fürth Tübingen Gießen Bückeburg Mönchengladbach
Fußball weiß heißen Spaß Maß Gruß süß Fuß bloß groß Schloß außen draußen
Bäckerei Metzgerei Kühlschrank Tür Schlüssel Brücke Bürger Gebäude Überraschung Ärger
Häuser Bäume Vögel Füße Hände Wörter Bücher Länder Mütter Väter Töchter Brüder
Märchen Gänseblümchen Würstchen Schwäne Flöte Kröte Möwe Höhle Mühle Röhre
zurück über für während später früh Zuständigkeit Möglichkeit Gemütlichkeit Übersetzung
""".split()

ES = """niño año España señor señora mañana pequeño cumpleaños corazón canción acción nación
Peña Muñoz Núñez Ibáñez Gómez Pérez Sánchez Martínez Rodríguez Fernández González López
José María Jesús Raúl Andrés Inés Ramón Joaquín Begoña Íñigo Sofía Lucía Adrián Álvaro
Málaga Cádiz Córdoba Almería León Jaén Ávila Logroño Mérida Cáceres Bogotá Perú México
también aquí allí después difícil fácil rápido último música teléfono pájaro árbol
¿qué? ¡olé! ¿cómo? ¡vámonos! pingüino cigüeña vergüenza agüero lingüística
ilusión televisión decisión opinión razón jardín camión avión limón algodón
sábado miércoles número público práctico económico político histórico
cañón otoño sueño dueño baño leña montaña compañía araña
""".split()

PT = """São Paulo João coração ação nação informação educação ônibus você até café
Conceição Gonçalves Magalhães Simões Guimarães Brandão Assunção Estêvão Tomé Inês Sônia
Antônio Jéssica Lúcia Márcio Fábio Flávia Cecília Mônica Vinícius Luíza Gonçalo Joaquim
Brasília Belém Maceió Goiânia Florianópolis Paraná Amapá Piauí Ceará Maranhão Pará Niterói
pão mãe irmã alemão cidadão órgão órfã lã maçã avô avó pé só nós
número música lâmpada máquina pássaro árvore câmara pêssego quilômetro
atenção opção solução canção estação região religião questão
não então também alguém ninguém porém além têm vêm põe
""".split()

CS = """Dvořák Čapek Šťastný Říha Ždárský Kříž Horák Novák Černý Procházka Kučera Veselý
Jiří Tomáš Lukáš Matěj Ondřej Vojtěch Šimon Kateřina Zuzana Tereza Barbora Anežka Jitka
Brno Plzeň Ostrava Olomouc Liberec Hradec Králové Pardubice České Budějovice Ústí Zlín Jihlava Třebíč Kroměříž
řeka město děti život škola čeština Česko přítel vítězství dědeček babička kůň růže
příliš žluťoučký úpěl ďábelské ódy čtvrť zmrzlina štěstí srdce věž hřích
čaj čas čtyři šest sedm devět deset dvanáct dvacet třicet sto tisíc
břeh dům můj tvůj sůl stůl vůz půl chléb mléko pivo víno jablko hruška
""".split()

PL = """Łódź Kraków Gdańsk Wrocław Poznań Białystok Rzeszów Toruń Częstochowa Kielce Zakopane Świnoujście
Wałęsa Kościuszko Żeromski Słowacki Mickiewicz Szymborska Miłosz Chopin Wójcik Kowalczyk Dąbrowski Zieliński
Łukasz Paweł Michał Wojciech Małgorzata Agnieszka Katarzyna Bożena Grażyna Jędrzej Bartłomiej Zuzanna
źródło żółw gęś jabłko pięć sześć dziewięć dziesięć jedenaście dwadzieścia
źdźbło zażółć gęślą jaźń mąka ręka łąka książka miłość przyjaźń wiadomość
cześć dziękuję proszę przepraszam dzień dobry wieczór noc tydzień miesiąc
żona mąż córka syn brat siostra dziadek babcia wujek ciocia
Wisła Odra Bałtyk Tatry Mazury Śląsk Pomorze Warmia
""".split()

HU = """Győr Pécs Szeged Debrecen Miskolc Nyíregyháza Kecskemét Székesfehérvár Szombathely Szolnok Érd Tatabánya
Kovács Szabó Tóth Nagy Horváth Varga Kiss Molnár Németh Farkas Balogh Papp Takács Juhász Lakatos Mészáros
Erzsébet Katalin Éva Zsófia Ildikó Ágnes Júlia Gyöngyi László István József Ferenc Sándor Gábor Péter Zoltán
őszibarack árvíztűrő tükörfúrógép gyümölcs könyv szőlő kő tő fű tű
köszönöm szeretlek egészségedre viszontlátásra jó éjszakát reggelt üdvözlöm
hűtőszekrény fürdőszoba nyelvtörő kőműves szövőszék gyűrű fésű bőrönd
Balaton Duna Tisza Hortobágy Pilis Mátra Bükk Őrség
""".split()

RU = """Москва Санкт-Петербург Новосибирск Екатеринбург Казань Нижний Новгород Челябинск Самара Омск Ростов Уфа Красноярск Пермь Воронеж Волгоград
Иванов Смирнов Кузнецов Попов Васильев Петров Соколов Михайлов Новиков Фёдоров Морозов Волков Алексеев Лебедев Семёнов Егоров
Александр Сергей Дмитрий Андрей Алексей Максим Евгений Иван Михаил Наталья Елена Ольга Татьяна Ирина Анна Юлия
привет спасибо пожалуйста здравствуйте до свидания хорошо плохо дом улица город
съешь же ещё этих мягких французских булок да выпей чаю
ёлка ёж объём подъезд семья вьюга щука чащоба хлеб молоко вода
книга школа учитель ученик работа время человек жизнь мир страна
""".split()

EL = """Αθήνα Θεσσαλονίκη Πάτρα Ηράκλειο Λάρισα Βόλος Ιωάννινα Χανιά Καβάλα Ρόδος Κέρκυρα Σπάρτη Δελφοί Ολυμπία
Παπαδόπουλος Γεωργίου Νικολάου Οικονόμου Δημητρίου Ιωάννου Κωνσταντίνου Βασιλείου Αντωνίου Παππάς
Γιώργος Δημήτρης Κώστας Νίκος Γιάννης Μαρία Ελένη Αικατερίνη Σοφία Δέσποινα Βασιλική Ευαγγελία
καλημέρα ευχαριστώ παρακαλώ γεια σου αντίο ναι όχι νερό ψωμί κρασί
ξεσκεπάζω ψυχοφθόρα βδελυγμία θάλασσα ουρανός ήλιος φεγγάρι αστέρι
αγάπη φιλία ελευθερία δημοκρατία φιλοσοφία ιστορία γεωγραφία μουσική
σπίτι δρόμος πόλη χωριό σχολείο δάσκαλος μαθητής βιβλίο τετράδιο
""".split()

TR = """İstanbul Ankara İzmir Bursa Antalya Adana Konya Gaziantep Şanlıurfa Kocaeli Mersin Diyarbakır Kayseri Eskişehir Muğla Çanakkale
Yılmaz Kaya Demir Şahin Çelik Yıldız Yıldırım Öztürk Aydın Özdemir Arslan Doğan Kılıç Aslan Çetin Kara Koç Kurt Özkan Şimşek
Ayşe Fatma Emine Hatice Zeynep Elif Özlem Gülşen Şükrü Mustafa Ömer Hüseyin Çağrı Doğukan Ilgın Işıl
ağaç çiçek güneş yağmur kış ılık soğuk sıcak dağ deniz göl ırmak
teşekkürler günaydın iyi akşamlar hoşça kal görüşürüz lütfen evet hayır
pijamalı hasta yağız şoföre çabucak güvendi öğretmen öğrenci kitap
çocuk kız oğlan anne baba kardeş şehir köy ülke dünya
""".split()

LANGS = {
    "French": ("Western", FR), "German": ("Western", DE), "Spanish": ("Western", ES),
    "Portuguese": ("Western", PT), "Czech": ("Central", CS), "Polish": ("Central", PL),
    "Hungarian": ("Central", HU), "Russian": ("Cyrillic", RU), "Greek": ("Greek", EL),
    "Turkish": ("Turkish", TR),
}

NBSP = " "
# Typographic punctuation decorations (curly quotes, en dash, euro, ellipsis, NBSP)
DECOR = [
    lambda a, b: f"“{a} {b}”",          # “a b”
    lambda a, b: f"{a} – {b}",                # a – b
    lambda a, b: f"{a}{NBSP}{b}",                  # a<NBSP>b
    lambda a, b: f"{a} {b}…",                 # a b…
    lambda a, b: f"{a} 12{NBSP}€",            # a 12 €
    lambda a, b: f"‘{a}’ {b}",           # ‘a’ b
    lambda a, b: f"{a} {b}",                       # plain
    lambda a, b: f"{a} {b}",                       # plain
]


def build_values(words):
    words = list(dict.fromkeys(words))
    base = (words * 3)[:100]
    vals = list(base)
    n = len(words)
    for i in range(100):
        a = words[i % n]
        b = words[(i * 7 + 3) % n]
        vals.append(DECOR[i % len(DECOR)](a, b))
    return vals
