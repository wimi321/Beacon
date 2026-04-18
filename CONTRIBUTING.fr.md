# Contribuer a Beacon

> Ce document est le guide de contribution en francais. En cas d ambiguite, la reference principale reste [`CONTRIBUTING.md`](./CONTRIBUTING.md).

Merci d aider Beacon a devenir plus fiable.

## Avant d ouvrir une PR

- Cherchez d abord les issues existantes pour eviter le travail en double.
- Nous preferons des PR petites et ciblees plutot que de grands refactors.
- Ajoutez des captures ou enregistrements pour les changements UI.
- Pour les bugs runtime, indiquez le modele de l appareil, la version de l OS et les etapes de reproduction.

## Environnement local

```bash
npm install
npm test
dart test
```

Si vous travaillez sur les shells mobiles :

```bash
npm run mobile:build
```

## Checklist Pull Request

- Les changements lies aux comportements d urgence doivent rester faciles a relire et a verifier.
- N introduisez aucun faux fallback IA.
- Preserve l approche offline-first lorsque le reseau est indisponible.
- Si vous modifiez la composition du prompt, la memoire de session, le retrieval ou le flux UI, mettez aussi les tests a jour.
- Le langage visible par l utilisateur doit rester simple, direct et lisible sous stress.

## Contributions a la base de connaissances

- Priorisez des sources medicales, de survie, meteorologiques et de securite publique faisant autorite.
- Respectez les licences et conditions de redistribution de chaque source.
- Ajoutez les nouvelles sources via le manifest et les scripts de build, pas en modifiant a la main les bundles generes.

## Changements sensibles a la securite

Si votre changement touche la signature, le packaging des modeles, les bridges natifs ou des logiques critiques de securite, ouvrez la PR avec davantage de contexte et de validation.
