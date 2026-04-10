#!/usr/bin/env python3
"""
Verbesserte halbautomatische Überarbeitung der Almanach-Body-TOMLs.
V2: Korrekte Extraktion, keine Duplikate, bessere Struktur.
"""

import os
import re
import sys
import tomllib
from pathlib import Path

# Etymologie-Datenbank (komplett)
BODY_DATA = {
    "sun": {
        "etymology": "Altenglisch sunne, germanisch *sunnōn; indoeuropäische Wurzel *séh₂ul. Das Wort ist in indogermanischen Sprachen weit verbreitet (lat. sol, gr. hḗlios, sanskr. sū́rya).",
        "discovery": "Prähistorisch; das Objekt definiert selbst den Begriff des Tageslichts.",
        "discoverer": "—"
    },
    "mercury": {
        "etymology": "Nach dem römischen Gott Mercurius (griech. Ἑρμῆς/Hermes). Symbol ☿ = Hermesstab.",
        "discovery": "Prähistorisch; als beweglicher 'Wanderstern' seit babylonischer Zeit (~14. Jh. v. Chr.)",
        "discoverer": "—"
    },
    "venus": {
        "etymology": "Nach der römischen Göttin Venus (griech. Ἀφροδίτη/Aphrodite). Symbol ♀ = stilisierter Handspiegel der Göttin.",
        "discovery": "Prähistorisch; bekannt bei Sumerern (Inanna, ~3000 v. Chr.) und Babyloniern (Ištar).",
        "discoverer": "—"
    },
    "terra": {
        "etymology": "Erde: germanisch *erþō (Boden). Terra: lat. für 'Land'. Symbol ♁ = Globus mit Meridianen.",
        "discovery": "—",
        "discoverer": "—"
    },
    "moon": {
        "etymology": "Engl. moon, germ. *mēnōþ- (Monat, Mond). Luna: lat., verwandt mit 'Licht' (levis). Symbol: ☽ (abnehmende Sichel).",
        "discovery": "Prähistorisch; definiert Monat und Gezeitenzyklus.",
        "discoverer": "—"
    },
    "mars": {
        "etymology": "Nach dem römischen Kriegsgott Mars (griech. Ἄρης/Ares). Symbol ♂ = Schild und Speer des Gottes.",
        "discovery": "Prähistorisch; Babylonier als Nergal (~7. Jh. v. Chr.).",
        "discoverer": "—"
    },
    "jupiter": {
        "etymology": "Nach dem römischen Göttervater Jupiter (griech. Ζεύς/Zeus). Symbol ♃ = stilisiertes Z.",
        "discovery": "Prähistorisch; Babylonier als Marduk.",
        "discoverer": "—"
    },
    "saturn": {
        "etymology": "Nach dem römischen Gott Saturnus (griech. Κρόνος/Kronos). Symbol ♄ = Sichel.",
        "discovery": "Prähistorisch; äußerster klassischer Planet.",
        "discoverer": "—"
    },
    "uranus": {
        "etymology": "Nach der griechischen Himmelsgottheit Οὐρανός (Uranos). Vorschlag Bode 1782; vorher 'Georgium Sidus' (Herschel).",
        "discovery": "1781-03-13 (erste dokumentierte Beobachtung als Planet)",
        "discoverer": "William Herschel"
    },
    "neptune": {
        "etymology": "Nach dem römischen Meeresgott Neptunus (griech. Ποσειδῶν/Poseidon). Vorschlag Le Verrier 1846. Symbol: ♆ = Dreizack.",
        "discovery": "1846-09-23 (visuelle Bestätigung)",
        "discoverer": "Johann G. Galle (nach Berechnungen von Le Verrier und Adams)"
    },
    "pluto": {
        "etymology": "Nach dem römischen Unterweltsgott Pluto (griech. Πλούτων). Vorschlag Venetia Burney (11-jährige Schülerin) 1930. Symbol: ♇ = PL-Monogramm.",
        "discovery": "1930-02-18 (Fotografische Aufnahme, Lowell Observatory)",
        "discoverer": "Clyde Tombaugh"
    },
    "ceres": {
        "etymology": "Nach der römischen Göttin Ceres (griech. Δημήτηρ/Demeter). Symbol: ⚳ = Sichel.",
        "discovery": "1801-01-01",
        "discoverer": "Giuseppe Piazzi"
    },
    "eris": {
        "etymology": "Nach der griechischen Göttin Ἔρις (Eris), Göttin der Zwietracht. Benennung 2006.",
        "discovery": "2003-10-21 (Aufnahmen), 2005-01-05 (Ankündigung)",
        "discoverer": "Michael E. Brown, Chad Trujillo, David L. Rabinowitz"
    },
    "haumea": {
        "etymology": "Nach der hawaiianischen Göttin Haumea der Geburt und Fruchtbarkeit.",
        "discovery": "2004-12-28 (Ankündigung 2005, Namensgabe 2008)",
        "discoverer": "Michael E. Brown et al.; unabhängig J. L. Ortiz Moreno et al."
    },
    "makemake": {
        "etymology": "Nach dem Schöpfergott der Rapa Nui (Osterinsel).",
        "discovery": "2005-03-31",
        "discoverer": "Michael E. Brown, Chad Trujillo, David L. Rabinowitz"
    },
    "gonggong": {
        "etymology": "Nach dem chinesischen Wassergott 共工 (Gònggōng). Namensgebung 2019.",
        "discovery": "2007-07-17 (Bilder), 2009 (Ankündigung)",
        "discoverer": "Megan E. Schwamb, Michael E. Brown, David L. Rabinowitz"
    },
    "quaoar": {
        "etymology": "Nach dem Tongva-Schöpfergott Quaoar (Mythologie Los Angeles Basin).",
        "discovery": "2002-06-04",
        "discoverer": "Chad Trujillo, Michael E. Brown"
    },
    "sedna": {
        "etymology": "Nach der inuitischen Meeresgöttin ᓴᓐᓇ (Sedna).",
        "discovery": "2003-11-14",
        "discoverer": "Michael E. Brown, Chad Trujillo, David L. Rabinowitz"
    },
    "orcus": {
        "etymology": "Nach dem etruskisch-römischen Unterweltsgott Orcus.",
        "discovery": "2004-02-17",
        "discoverer": "Michael E. Brown, Chad Trujillo, David L. Rabinowitz"
    },
    "io": {
        "etymology": "Nach Io (griech. Ἰώ), von Zeus verfolgte Priestertochter, in Kuh verwandelt, floh über den Bosporus.",
        "discovery": "1610-01-07 (Beobachtung), 1610 (Sidereus Nuncius)",
        "discoverer": "Galileo Galilei (unabhängig: Simon Marius)"
    },
    "europa": {
        "etymology": "Nach der phönizischen Königstochter Εὐρώπη (Eurṓpē), von Zeus als Stier entführt.",
        "discovery": "1610-01-07",
        "discoverer": "Galileo Galilei (unabhängig: Simon Marius)"
    },
    "ganymede": {
        "etymology": "Nach Γανυμήδης (Ganymēdēs), trojanischer Prinz, Mundschenk der Götter.",
        "discovery": "1610-01-07",
        "discoverer": "Galileo Galilei (unabhängig: Simon Marius)"
    },
    "callisto": {
        "etymology": "Nach Καλλιστώ (Kallistṓ), Nymphe, von Hera in Bärin verwandelt (Ursa Major).",
        "discovery": "1610-01-07",
        "discoverer": "Galileo Galilei (unabhängig: Simon Marius)"
    },
    "titan": {
        "etymology": "Nach den Τιτᾶνες (Titanes), Urgeschlecht der griechischen Götter.",
        "discovery": "1655-03-25",
        "discoverer": "Christiaan Huygens"
    },
    "enceladus": {
        "etymology": "Nach Ἐγκέλαδος (Enkélados), Gigant, von Athene unter Sizilien begraben (Ätna = sein Atem).",
        "discovery": "1789-08-28",
        "discoverer": "William Herschel"
    },
    "triton": {
        "etymology": "Nach Τρίτων (Trítōn), Sohn Poseidons/Neptuns, Meeresgott mit Dreizack.",
        "discovery": "1846-10-10 (16 Tage nach Neptun)",
        "discoverer": "William Lassell"
    },
    "charon": {
        "etymology": "After Χάρων (Chárōn), Fährmann der Toten. 'C-H' = Christy + Charlene.",
        "discovery": "1978-06-22 (Aufnahme), 1978-07-07 (Bestätigung)",
        "discoverer": "James W. Christy"
    },
    "deimos": {
        "etymology": "Nach Δεῖμος (Deimos), Sohn des Ares, Personifikation der Furcht.",
        "discovery": "1877-08-12",
        "discoverer": "Asaph Hall"
    },
    "phobos": {
        "etymology": "Nach Φόβος (Phobos), Sohn des Ares, Personifikation der Panik.",
        "discovery": "1877-08-18",
        "discoverer": "Asaph Hall"
    },
    "dione": {
        "etymology": "Nach Διώνη (Diṓnē), Tochter des Okeanos, Mutter der Aphrodite.",
        "discovery": "1684-03-21",
        "discoverer": "Giovanni Cassini"
    },
    "rhea": {
        "etymology": "Nach Ῥέᾱ (Rheā), Titanin, Mutter Zeus', Gattin des Kronos.",
        "discovery": "1672-12-23",
        "discoverer": "Giovanni Cassini"
    },
    "tethys": {
        "etymology": "Nach Τηθύς (Tēthýs), Titanin, Mutter der Okeaniden und Flüsse.",
        "discovery": "1684-03-21",
        "discoverer": "Giovanni Cassini"
    },
    "mimas": {
        "etymology": "Nach Μῖμᾱς (Mīmās), Gigant, von Hephaistos/Hephaestus getötet.",
        "discovery": "1789-09-17",
        "discoverer": "William Herschel"
    },
    "iapetus": {
        "etymology": "Nach Ἰαπετός (Iapetós), Titan, Vater von Atlas und Prometheus.",
        "discovery": "1671-10-25",
        "discoverer": "Giovanni Cassini"
    },
    "hyperion": {
        "etymology": "Nach Ὑπερίων (Hyperíōn), Titan des Lichts, Vater des Helios.",
        "discovery": "1848-09-16",
        "discoverer": "William Bond, George Bond, William Lassell"
    },
    "phoebe": {
        "etymology": "Nach Φοίβη (Phoíbē), Titanin, Mutter der Leto.",
        "discovery": "1898-08-16",
        "discoverer": "William Henry Pickering"
    },
    "janus": {
        "etymology": "Nach dem römischen Gott Janus (Gott der Türen, Anfänge).",
        "discovery": "1966-12-15 (Audouin Dollfus); 1978-02 (bestätigt Voyager 1)",
        "discoverer": "Audouin Dollfus / Voyager 1 Team"
    },
    "epimetheus": {
        "etymology": "Nach Ἐπιμηθεύς (Epimētheús), Titan der Nachsicht, Bruder des Prometheus.",
        "discovery": "1966 (Dollfus); 1978 (bestätigt)",
        "discoverer": "Audouin Dollfus / Voyager 1 Team"
    },
    "prometheus": {
        "etymology": "Nach Προμηθεύς (Promētheús), Titan der Voraussicht, Feuerbringer.",
        "discovery": "1980 (Voyager 1)",
        "discoverer": "Voyager 1 Imaging Team"
    },
    "pandora": {
        "etymology": "Nach Πανδώρα (Pandṓra), die 'Allbeschenkte', erste Frau der Mythologie.",
        "discovery": "1980 (Voyager 1)",
        "discoverer": "Voyager 1 Imaging Team"
    },
    "ariel": {
        "etymology": "Nach Ariel (Geist aus Shakespeares 'Der Sturm').",
        "discovery": "1851-10-24 (Lassell); 1851-11 (Herschel bestätigt)",
        "discoverer": "William Lassell"
    },
    "umbriel": {
        "etymology": "Nach Umbriel (düsterer Geist aus Popes 'The Rape of the Lock').",
        "discovery": "1851-10-24",
        "discoverer": "William Lassell"
    },
    "titania": {
        "etymology": "After Titania (Königin der Feen in Shakespeares 'Sommernachtstraum').",
        "discovery": "1787-01-11",
        "discoverer": "William Herschel"
    },
    "oberon": {
        "etymology": "Nach Oberon (König der Feen in 'Sommernachtstraum').",
        "discovery": "1787-01-11",
        "discoverer": "William Herschel"
    },
    "miranda": {
        "etymology": "Nach Miranda (Heldin in Shakespeares 'Der Sturm').",
        "discovery": "1948-02-16",
        "discoverer": "Gerard Kuiper"
    },
    "nereid": {
        "etymology": "Nach Νηρηΐδες (Nērēḯdes), die 50 Meeresnymphen, Töchter Nereus'.",
        "discovery": "1949-05-01",
        "discoverer": "Gerard Kuiper"
    },
    "proteus": {
        "etymology": "Nach Πρωτεύς (Prōteús), Meeresgott, Gestaltwandler, Diener Poseidons.",
        "discovery": "1989-06-16 (Voyager 2)",
        "discoverer": "Voyager 2 Imaging Team"
    },
    "larissa": {
        "etymology": "Nach Λάρισσα (Larissa), Geliebte des Poseidon, Nymphe.",
        "discovery": "1981-05-24 (Reitsema et al., Sternbedeckung); 1989 (Voyager 2 bestätigt)",
        "discoverer": "Harold Reitsema et al. / Voyager 2"
    },
    "galatea": {
        "etymology": "Nach Γαλάτεια (Galáteia), eine der 50 Nereiden, Geliebte des Kyklopen Polyphem.",
        "discovery": "1989-07-01 (Voyager 2)",
        "discoverer": "Voyager 2 Imaging Team (Stephen Synnott)"
    },
    "despina": {
        "etymology": "Nach Δεσποίνη (Despoina), eine der 50 Nereiden.",
        "discovery": "1989-07-01 (Voyager 2)",
        "discoverer": "Voyager 2 Imaging Team (Stephen Synnott)"
    },
    "thalassa": {
        "etymology": "Nach Θάλασσα (Thálassa), Göttin des Meeres, Tochter Aether und Hemera.",
        "discovery": "1989 (Voyager 2)",
        "discoverer": "Voyager 2 Imaging Team"
    },
    "naiad": {
        "etymology": "Nach Ναϊάς (Naiás), eine Nymphe fließender Gewässer (Flüsse, Quellen).",
        "discovery": "1989 (Voyager 2)",
        "discoverer": "Voyager 2 Imaging Team"
    },
    "halley": {
        "etymology": "Nach Edmond Halley (1656–1742), englischer Astronom, berechnete die Periodizität.",
        "discovery": "Antike (erwähnt von chinesischen, babylonischen Astronomen); periodische Natur erkannt 1705",
        "discoverer": "Edmond Halley (Periodizität); antike Kulturen (Erscheinungen)"
    },
    "encke": {
        "etymology": "Nach Johann Franz Encke (1791–1865), deutsch Astronom, berechnete die Bahn.",
        "discovery": "1786 (Pierre Méchain); Wiederentdeckung 1818, Bahn von Encke berechnet",
        "discoverer": "Pierre Méchain (Entdeckung); Johann Franz Encke (Berechnung)"
    },
    "borrelly": {
        "etymology": "Nach Alphonse Louis Nicolas Borrelly (1842–1926), französischer Astronom.",
        "discovery": "1904-12-28",
        "discoverer": "Alphonse Borrelly"
    },
    "wild2": {
        "etymology": "Nach Paul Wild (1925–2014), schweizer Astronom, Entdecker zahlreicher Kometen.",
        "discovery": "1978-01-06",
        "discoverer": "Paul Wild"
    },
    "churyumov_gerasimenko": {
        "etymology": "Nach Klim Churyumov (1937–2016) und Svetlana Gerasimenko (*1945), ukrainische/russische Astronomen.",
        "discovery": "1969-09-11 (Plattenaufnahme), 1969-09-23 (identifiziert)",
        "discoverer": "Klim Churyumov, Svetlana Gerasimenko"
    },
    "tempel1": {
        "etymology": "Nach Wilhelm Tempel (1821–1889), deutsch Astronom, entdeckte viele Kometen und Nebel.",
        "discovery": "1867-04-03",
        "discoverer": "Wilhelm Tempel"
    },
    "hartley2": {
        "etymology": "Nach Malcolm Hartley (*1957), australischer Astronom am UK Schmidt Telescope.",
        "discovery": "1986-03-15",
        "discoverer": "Malcolm Hartley"
    },
    "wirtanen": {
        "etymology": "Nach Carl Alvar Wirtanen (1910–1990), US-amerikanischer Astronom finnischer Herkunft.",
        "discovery": "1948-01-17",
        "discoverer": "Carl A. Wirtanen"
    },
    "swift_tuttle": {
        "etymology": "Nach Lewis Swift (1820–1913) und Horace Parnell Tuttle (1837–1893), US-amerikanische Astronomen.",
        "discovery": "1862-07-16",
        "discoverer": "Lewis Swift, Horace Parnell Tuttle"
    },
    "himalia": {
        "etymology": "Nach Ἱμαλία (Himalia), Nymphe, Mutter der Schäfer (auf Kos).",
        "discovery": "1904-12-03",
        "discoverer": "Charles Dillon Perrine"
    },
    "amalthea": {
        "etymology": "Nach Ἀμάλθεια (Amáltheia), Ziege, die das Zeus-Kind nährte.",
        "discovery": "1892-09-09",
        "discoverer": "Edward Emerson Barnard"
    },
    "elara": {
        "etymology": "Nach Ἔλαρα (Elara), eine der Liebsten Zeus', Mutter des Giganten Tityos.",
        "discovery": "1905-01-02",
        "discoverer": "Charles Dillon Perrine"
    },
    "pasiphae": {
        "etymology": "Nach Πασιφάη (Pasipháē), Frau des Minos, Mutter des Minotaurus.",
        "discovery": "1908-01-28",
        "discoverer": "Philbert Jacques Melotte"
    },
    "sinope": {
        "etymology": "Nach Σινώπη (Sinṓpē), Tochter des Flussgottes Asopos, von Zeus entführt.",
        "discovery": "1914-07-21",
        "discoverer": "Seth Barnes Nicholson"
    },
    "lysithea": {
        "etymology": "Nach Λυσιθέα (Lysithéa), eine der 50 Nereiden.",
        "discovery": "1938-07-06",
        "discoverer": "Seth Barnes Nicholson"
    },
    "carme": {
        "etymology": "After Κάρμη (Kármē), Mutter des Britomartis (kretische Göttin).",
        "discovery": "1938-07-30",
        "discoverer": "Seth Barnes Nicholson"
    },
    "ananke": {
        "etymology": "Nach Ἀνάγκη (Anánkē), Göttin der Notwendigkeit, Mutter der Moiren (Schicksalsgöttinnen).",
        "discovery": "1951-09-28",
        "discoverer": "Seth Barnes Nicholson"
    },
    "leda": {
        "etymology": "Nach Λήδα (Lḗda), Königin von Sparta, Mutter von Helena und den Dioskuren.",
        "discovery": "1974-09-11",
        "discoverer": "Charles Kowal"
    },
    "thebe": {
        "etymology": "After Θήβη (Thḗbē), Nymphe, Geliebte Zeus', Mutter von Aigypios.",
        "discovery": "1979-03-05 (Voyager 1)",
        "discoverer": "Stephen Synnott (Voyager 1)"
    },
    "metis": {
        "etymology": "After Μῆτις (Mē̂tis), Titanin der List, erste Gemahlin Zeus', Mutter Athenes.",
        "discovery": "1979-03-04 (Voyager 1)",
        "discoverer": "Stephen Synnott (Voyager 1)"
    },
    "adrastea": {
        "etymology": "Nach Ἀδράστεια (Adrasteia), Nymphe, eine der Amme des Zeus-Kindes.",
        "discovery": "1979-07-08 (Voyager 2)",
        "discoverer": "David Jewitt, G. Edward Danielson (Voyager 2)"
    },
    "callirrhoe": {
        "etymology": "After Καλλιρρόη (Kallirrhóē), Okeanide, Gemahlin des Chrysaor.",
        "discovery": "1999-10-06",
        "discoverer": "Spacewatch / James V. Scotti et al."
    },
    "themisto": {
        "etymology": "After Θεμιστώ (Themistṓ), eine der 50 Nereiden.",
        "discovery": "1975 (Kowal); verloren, 2000 wiederentdeckt (Sheppard et al.)",
        "discoverer": "Charles Kowal (1975); David Jewitt et al. (2000)"
    },
    "magaclite": {
        "etymology": "After Μεγακλείτη (Megakleítē), eine der 50 Nereiden.",
        "discovery": "2000-11-25",
        "discoverer": "Scott S. Sheppard et al."
    },
    "taygete": {
        "etymology": "After Ταϋγέτη (Taügétē), eine der 50 Nereiden.",
        "discovery": "2000-11-25",
        "discoverer": "Scott S. Sheppard et al."
    },
    "chaldene": {
        "etymology": "After Χαλδήνη (Chaldḗnē), eine der 50 Nereiden.",
        "discovery": "2000-11-23",
        "discoverer": "Scott S. Sheppard et al."
    },
    "harpalyke": {
        "etymology": "After Ἁρπαλύκη (Harpalýkē), eine der 50 Nereiden.",
        "discovery": "2000-11-23",
        "discoverer": "Scott S. Sheppard et al."
    },
    "kalyke": {
        "etymology": "After Καλύκη (Kalýkē), eine der 50 Nereiden.",
        "discovery": "2000-11-23",
        "discoverer": "Scott S. Sheppard et al."
    },
    "iocaste": {
        "etymology": "After Ἰοκάστη (Iokástē), Gemahlin und Mutter Ödipus'.",
        "discovery": "2000-11-23",
        "discoverer": "Scott S. Sheppard et al."
    },
    "erinome": {
        "etymology": "After Ἐρινόμη (Erinómē), eine der 50 Nereiden.",
        "discovery": "2000-11-23",
        "discoverer": "Scott S. Sheppard et al."
    },
    "isonoe": {
        "etymology": "After Ἰσονόη (Isonóē), eine der 50 Nereiden.",
        "discovery": "2000-11-23",
        "discoverer": "Scott S. Sheppard et al."
    },
    "praxidike": {
        "etymology": "After Πραξιδίκη (Praxidíkē), Göttin der Strafgerechtigkeit.",
        "discovery": "2000-11-23",
        "discoverer": "Scott S. Sheppard et al."
    },
    "autonoe": {
        "etymology": "After Αὐτονόη (Autonóē), Tochter des Kadmos, Mutter des Aktäon.",
        "discovery": "2001-12-10",
        "discoverer": "Scott S. Sheppard et al."
    },
    "thyone": {
        "etymology": "After Θυώνη (Thuṓnē), Göttin der Inspiration, Geliebte Apollons.",
        "discovery": "2001-12-11",
        "discoverer": "Scott S. Sheppard et al."
    },
    "hermippe": {
        "etymology": "After Ἑρμίππη (Hermíppē), eine der 50 Nereiden.",
        "discovery": "2001-12-09",
        "discoverer": "Scott S. Sheppard et al."
    },
    "aitne": {
        "etymology": "After Αἴτνη (Aítnē), Nymphe des Ätna, Geliebte des Zeus.",
        "discovery": "2001-12-11",
        "discoverer": "Scott S. Sheppard et al."
    },
    "eurydome": {
        "etymology": "After Εὐρυδόμη (Eurydómē), eine der 50 Nereiden.",
        "discovery": "2001-12-09",
        "discoverer": "Scott S. Sheppard et al."
    },
    "euanthe": {
        "etymology": "After Εὐάνθη (Euánthē), eine der 50 Nereiden.",
        "discovery": "2001-12-11",
        "discoverer": "Scott S. Sheppard et al."
    },
    "euporie": {
        "etymology": "After Εὐπορίη (Euporíē), eine der 50 Nereiden.",
        "discovery": "2001-12-11",
        "discoverer": "Scott S. Sheppard et al."
    },
    "orthosie": {
        "etymology": "After Ὀρθοσία (Orthosía), eine der 50 Nereiden.",
        "discovery": "2001-12-11",
        "discoverer": "Scott S. Sheppard et al."
    },
    "sponde": {
        "etymology": "After Σπονδή (Spondḗ), eine der 50 Nereiden.",
        "discovery": "2001-12-09",
        "discoverer": "Scott S. Sheppard et al."
    },
    "kale": {
        "etymology": "After Καλή (Kalḗ), eine der 50 Nereiden.",
        "discovery": "2001-12-09",
        "discoverer": "Scott S. Sheppard et al."
    },
    "pasithee": {
        "etymology": "After Πασιθέα (Pasithéa), eine der 50 Nereiden.",
        "discovery": "2001-12-11",
        "discoverer": "Scott S. Sheppard et al."
    },
    "hegemone": {
        "etymology": "After Ἡγεμόνη (Hēgemónē), eine der 50 Nereiden.",
        "discovery": "2003-02-08",
        "discoverer": "Scott S. Sheppard et al."
    },
    "mneme": {
        "etymology": "After Μνήμη (Mnḗmē), eine der 50 Nereiden.",
        "discovery": "2003-02-08",
        "discoverer": "Scott S. Sheppard et al."
    },
    "aoede": {
        "etymology": "After Ἀοιδή (Aoidḗ), eine der 50 Nereiden.",
        "discovery": "2003-02-08",
        "discoverer": "Scott S. Sheppard et al."
    },
    "thelxinoe": {
        "etymology": "After Θελξινόη (Thelxinóē), eine der 50 Nereiden.",
        "discovery": "2003-02-09",
        "discoverer": "Scott S. Sheppard et al."
    },
    "arche": {
        "etymology": "After Ἀρχή (Archḗ), eine der 50 Nereiden.",
        "discovery": "2002-10-31",
        "discoverer": "Scott S. Sheppard et al."
    },
    "kallichore": {
        "etymology": "After Καλλιχόρη (Kallichórē), eine der 50 Nereiden.",
        "discovery": "2003-02-06",
        "discoverer": "Scott S. Sheppard et al."
    },
    "helieke": {
        "etymology": "After Ἑλίκη (Helíkē), eine der 50 Nereiden.",
        "discovery": "2003-02-06",
        "discoverer": "Scott S. Sheppard et al."
    },
    "carpo": {
        "etymology": "After Καρπώ (Karpṓ), eine der 50 Nereiden.",
        "discovery": "2003-02-09",
        "discoverer": "Scott S. Sheppard et al."
    },
    "eukelade": {
        "etymology": "After Εὐκελάδη (Eukeládē), eine der 50 Nereiden.",
        "discovery": "2003-02-06",
        "discoverer": "Scott S. Sheppard et al."
    },
    "cyllene": {
        "etymology": "After Κυλλήνη (Kyllḗnē), eine der 50 Nereiden.",
        "discovery": "2003-02-09",
        "discoverer": "Scott S. Sheppard et al."
    },
    "kore": {
        "etymology": "After Κόρη (Kórē), eine der 50 Nereiden.",
        "discovery": "2003-02-08",
        "discoverer": "Scott S. Sheppard et al."
    },
    "herse": {
        "etymology": "After Ἕρση (Hérsē), Tochter des Kekrops, Geliebte des Hermes.",
        "discovery": "2003-02-16",
        "discoverer": "Scott S. Sheppard et al."
    },
    "dia": {
        "etymology": "After Δῖα (Dîa), eine der 50 Nereiden.",
        "discovery": "2000-12-05",
        "discoverer": "Scott S. Sheppard et al."
    },
    "elara": {
        "etymology": "After Ἔλαρα (Elara), Geliebte Zeus', Mutter des Tityos.",
        "discovery": "1905-01-02",
        "discoverer": "Charles Dillon Perrine"
    },
    "carpo": {
        "etymology": "Nach Καρπώ (Karpṓ), Nymphe der Fruchtbarkeit.",
        "discovery": "2003-02-09",
        "discoverer": "Scott S. Sheppard et al."
    },
    "valetudo": {
        "etymology": "Nach der römischen Göttin der Gesundheit (lat. valetudo = Gesundheit).",
        "discovery": "2016-03-23",
        "discoverer": "Scott S. Sheppard et al."
    },
    "pandia": {
        "etymology": "Nach Πανδία (Pandía), Göttin des Vollmonds, Tochter Zeus' und Selenes.",
        "discovery": "2017-03-23",
        "discoverer": "Scott S. Sheppard et al."
    },
    "ersa": {
        "etymology": "Nach Ἔρσα (Érsa), Göttin des Morgentaus, Tochter Zeus' und Selenes.",
        "discovery": "2018-05-30",
        "discoverer": "Scott S. Sheppard et al."
    },
    "philophrosyne": {
        "etymology": "Nach Φιλοφροσύνη (Philophrosýnē), eine der 50 Nereiden.",
        "discovery": "2003",
        "discoverer": "Scott S. Sheppard et al."
    },
    "eirene": {
        "etymology": "Nach Εἰρήνη (Eirḗnē), Göttin des Friedens, eine der 50 Nereiden.",
        "discovery": "2003",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2003_j_2": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2003",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2003_j_4": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2003",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2003_j_9": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2003",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2003_j_10": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2003",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2003_j_12": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2003",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2003_j_16": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2003",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2003_j_18": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2003",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2003_j_19": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2003",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2003_j_23": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2003",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2003_j_24": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2003",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2011_j_1": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2011",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2011_j_2": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2011",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2016_j_1": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2016",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2016_j_2": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2016",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2017_j_1": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2017",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2017_j_2": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2017",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2017_j_3": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2017",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2017_j_5": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2017",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2017_j_6": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2017",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2017_j_7": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2017",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2017_j_8": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2017",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2017_j_9": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2017",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2018_j_2": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2018",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2018_j_3": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2018",
        "discoverer": "Scott S. Sheppard et al."
    },
    "s_2018_j_4": {
        "etymology": "Provisorische Bezeichnung; keine Namenvergabe.",
        "discovery": "2018",
        "discoverer": "Scott S. Sheppard et al."
    },
}

default_entry = {
    "etymology": "Benennung nach mythologischer oder kultureller Referenz.",
    "discovery": "Entdeckungsdatum nicht spezifiziert.",
    "discoverer": "—"
}

def get_body_info(body_id: str) -> dict:
    """Liefert Etymologie, Entdeckung und Entdecker für einen Körper."""
    return BODY_DATA.get(body_id, default_entry)


def extract_scientific_content(old_desc: str) -> str:
    """
    Extrahiert den wissenschaftlichen Inhalt ohne doppelte Metadaten.
    """
    lines = old_desc.split('\n')
    result = []
    skip_until_content = False
    
    for line in lines:
        # Überspringe Etymology/Entdeckung-Blöcke
        if '[b]Etymologie[/b]' in line or '[b]Entdeckung[/b]' in line:
            skip_until_content = True
            continue
        
        # Stoppe Überspringen bei Beschreibung
        if '[b]Beschreibung[/b]' in line:
            skip_until_content = False
            continue
        
        if not skip_until_content:
            result.append(line)
    
    # Wenn kein Beschreibung-Tag gefunden, nutze alles nach dem ersten Absatz
    if not result:
        paragraphs = [p.strip() for p in old_desc.split('\n\n') if p.strip()]
        if len(paragraphs) > 1:
            # Ersten Absatz überspringen (meist redundant mit phys. Parametern)
            return '\n\n'.join(paragraphs[1:])
        return old_desc
    
    return '\n'.join(result).strip()


def process_body_file(filepath: Path) -> bool:
    """Verarbeitet eine einzelne Body-TOML-Datei."""
    try:
        with open(filepath, 'rb') as f:
            data = tomllib.load(f)
        
        body_id = data.get('id', filepath.stem)
        old_desc = data.get('description', '')
        
        if not old_desc:
            print(f"⚠️  {filepath.name}: Keine description gefunden")
            return False
        
        info = get_body_info(body_id)
        scientific_content = extract_scientific_content(old_desc)
        
        # Neue strukturierte Beschreibung
        new_desc = f"""[b]{body_id.capitalize()}[/b]

[b]Etymologie[/b]
{info['etymology']}

[b]Entdeckung[/b]
Datum: {info['discovery']}
Entdecker: {info['discoverer']}

[b]Physikalische Eigenschaften[/b]
{scientific_content}"""
        
        # TOML-Output
        output = f'id = "{body_id}"\n\ndescription = """\\\n{new_desc}\n"""\n'
        
        # Infoboxen beibehalten
        if 'infobox' in data:
            for section, values in data['infobox'].items():
                output += f'\n[infobox.{section}]\n'
                for key, val in values.items():
                    if isinstance(val, dict):
                        output += f'\n[infobox.{section}.{key}]\n'
                        for k2, v2 in val.items():
                            output += f'"{k2}" = {v2}\n'
                    elif isinstance(val, (int, float)):
                        output += f'{key} = {val}\n'
                    else:
                        output += f'{key} = "{val}"\n'
        
        # Backup nur einmal
        backup_path = filepath.with_suffix('.toml.bak')
        if not backup_path.exists():
            filepath.rename(backup_path)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(output)
        
        print(f"✅ {filepath.name}")
        return True
        
    except Exception as e:
        print(f"❌ Fehler bei {filepath.name}: {e}")
        return False


def main():
    """Hauptfunktion: Verarbeitet alle Body-TOMLs."""
    bodies_dir = Path(__file__).parent.parent / 'data' / 'almanach' / 'source' / 'bodies'
    
    if not bodies_dir.exists():
        print(f"❌ Verzeichnis nicht gefunden: {bodies_dir}")
        sys.exit(1)
    
    toml_files = sorted(bodies_dir.glob('*.toml'))
    print(f"📁 Gefunden: {len(toml_files)} Body-Dateien")
    print("=" * 50)
    
    success = 0
    failed = 0
    
    for toml_file in toml_files:
        if process_body_file(toml_file):
            success += 1
        else:
            failed += 1
    
    print("=" * 50)
    print(f"✅ Erfolgreich: {success}")
    print(f"❌ Fehlgeschlagen: {failed}")


if __name__ == '__main__':
    main()
