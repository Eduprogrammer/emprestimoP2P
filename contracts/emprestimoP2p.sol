// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract emprestimoP2p {
    uint256 public proximoIdEmprestimo;
    
    enum statusDoEmprestimo {
        Ativo,
        Pago,
        Vencido
    }

    struct emprestimo {
        address credor;
        address devedor;
        uint256 valorPrincipal;
        uint256 valorDevido;
        uint256 prazoFinal;
        statusDoEmprestimo status;
    }

    mapping(uint256 => emprestimo) public emprestimos;

    event emprestimoIniciado(uint256 indexed idEmprestimo, address indexed credor, uint256 valorPrincipal, uint256 valorDevido,
    uint256 prazoFinal);
    event emprestimoSacado(uint256 indexed idEmprestimo, address indexed devedor);
    event emprestimoPago(uint256 indexed idEmprestimo, address indexed devedor, uint256 indexed valorPago);
    event reembolsoSacado(uint256 indexed idEmprestimo, address indexed credor, uint256 indexed valorSacado);

    function iniciarEmprestimo(address _devedor, uint256 _valorPrincipal, uint256 _taxaJuros, uint256 _prazoEmDias) public payable {
        require(msg.value == _valorPrincipal, "Valor enviado de ser igual ao valor principal.");
        require(_valorPrincipal > 0, "Valor principal deve ser maior que zero.");
        require(_taxaJuros <= 1000, "Taxa de juros nao pode exceder 100% (1000 permil).");
        require(_prazoEmDias > 0, "O Prazo deve ser maior que zero dias.");

        uint256 valorDevidoCalculado = _valorPrincipal + (_valorPrincipal * _taxaJuros / 1000);
        uint256 prazoFinalCalculado = block.timestamp + (_prazoEmDias * 1 days);

        emprestimos[proximoIdEmprestimo] = emprestimo({
            credor: msg.sender,
            devedor: _devedor,
            valorPrincipal: _valorPrincipal,
            valorDevido:valorDevidoCalculado,
            prazoFinal: prazoFinalCalculado,
            status: statusDoEmprestimo.Ativo
        });

        emit emprestimoIniciado(proximoIdEmprestimo, msg.sender,  _valorPrincipal, valorDevidoCalculado, prazoFinalCalculado);
        proximoIdEmprestimo++;
    }

    function sacarEmprestimo(uint256 _idEmprestimo) public {
        require(_idEmprestimo < proximoIdEmprestimo, "Emprestimo nao existe.");
        emprestimo storage _emprestimo = emprestimos[_idEmprestimo];

        require(_emprestimo.status == statusDoEmprestimo.Ativo, "Emprestimo nao esta ativo.");
        require(_emprestimo.devedor == msg.sender, "Apenas o devedor pode sacar este emprestimo");
        require(_emprestimo.valorPrincipal > 0, "O valor principal deve ser maior que zero.");

        // Transferir o valor principal para o devedor

        (bool success, ) = payable(_emprestimo.devedor).call{value: _emprestimo.valorPrincipal} ("");
        require(success, "Falha ao sacar o emprestimo");

        _emprestimo.valorPrincipal = 0; // zera o principal para evitar saques dublicados
        emit emprestimoSacado(_idEmprestimo, msg.sender);

    }

    function pagarEmprestimo(uint256 _idEmprestimo) public payable {
        require(_idEmprestimo < proximoIdEmprestimo, "Emprestimo nao esiste.");
        emprestimo storage _emprestimo = emprestimos[_idEmprestimo];

        require(_emprestimo.status == statusDoEmprestimo.Ativo || _emprestimo.status == statusDoEmprestimo.Vencido, "Emprestimo nao esta ativo ou vencido");
        require(_emprestimo.devedor == msg.sender, "Apenas o devedor pode pagar este emprestimo");
        require(msg.value >= _emprestimo.valorDevido, "Valor pago insuficiente.");

        _emprestimo.status = statusDoEmprestimo.Pago;
        emit emprestimoPago(_idEmprestimo, msg.sender, msg.value);

    }

    function sacarReembolso(uint256 _idEmprestimo) public {
        require(_idEmprestimo < proximoIdEmprestimo, "Emprestimo nao esiste.");
        emprestimo storage _emprestimo = emprestimos[_idEmprestimo];

        require(_emprestimo.status == statusDoEmprestimo.Pago, "Emprestimo nao foi pago.");
        require(_emprestimo.credor == msg.sender, "Apenas o credor pode sacar o reembolso.");
        require(address(this).balance >= _emprestimo.valorDevido, "Contrato nao tem fundos suficientes.");

        //Transferir o reembolso para o credor

        (bool success, ) = payable(_emprestimo.credor).call{value: _emprestimo.valorDevido} ("");
        require(success, "Falha ao sacar o reembolso.");

    }

     function verificaStatusEmprestimo(uint256 _idEmprestimo) public view returns (uint256) {
        // Validação correta: o ID deve ser menor que o próximo ID disponível (o que significa que o empréstimo existe)
        require(_idEmprestimo < proximoIdEmprestimo, "Emprestimo nao existe.");
        
        // Obter a instância do empréstimo
        emprestimo storage _emprestimo = emprestimos[_idEmprestimo];

        // Se o empréstimo já foi pago, o valor devido é 0
        if (_emprestimo.status == statusDoEmprestimo.Pago) {
            return 0;
        }

        // Se o empréstimo não foi pago, retorne o valorDevido que já foi calculado e armazenado
        // no momento em que o empréstimo foi iniciado.
        return _emprestimo.valorDevido;

     }
}