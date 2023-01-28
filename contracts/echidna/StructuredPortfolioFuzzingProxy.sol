// SPDX-License-Identifier: BUSL-1.1
// Business Source License 1.1
// License text copyright (c) 2017 MariaDB Corporation Ab, All Rights Reserved. "Business Source License" is a trademark of MariaDB Corporation Ab.

// Parameters
// Licensor: TrueFi Foundation Ltd.
// Licensed Work: Structured Credit Vaults. The Licensed Work is (c) 2022 TrueFi Foundation Ltd.
// Additional Use Grant: Any uses listed and defined at this [LICENSE](https://github.com/trusttoken/contracts-carbon/license.md)
// Change Date: December 31, 2025
// Change License: MIT

pragma solidity ^0.8.16;

import {FixedInterestOnlyLoans} from "../test/FixedInterestOnlyLoans.sol";
import {Status} from "../interfaces/IStructuredPortfolio.sol";
import {StructuredPortfolio} from "../StructuredPortfolio.sol";
import {StructuredPortfolioFuzzingInit} from "./StructuredPortfolioFuzzingInit.sol";
import {ITrancheVault} from "../interfaces/ITrancheVault.sol";
import {AddLoanParams} from "../interfaces/ILoansManager.sol";

uint256 constant DAY = 1 days;

contract StructuredPortfolioFuzzingProxy is StructuredPortfolioFuzzingInit {
    bool public echidna_check_waterfallContinuous = true;

    function echidna_check_statusIsNotCapitalFormation() public view returns (bool) {
        return structuredPortfolio.status() != Status.CapitalFormation;
    }

    function echidna_check_statusIsCapitalFormation() public view returns (bool) {
        return structuredPortfolio.status() == Status.CapitalFormation;
    }

    function markLoanAsDefaulted(uint256 rawLoanId) public {
        uint256 loanId = rawLoanId % structuredPortfolio.getActiveLoans().length;
        structuredPortfolio.markLoanAsDefaulted(loanId);
    }

    function deposit(uint256 rawAmount, uint8 rawTrancheId) public {
        uint256 trancheId = rawTrancheId % 3;
        uint256 amount = rawAmount % token.balanceOf(address(lender));
        ITrancheVault tranche;
        if (trancheId == 0) {
            tranche = equityTranche;
        } else if (trancheId == 1) {
            tranche = juniorTranche;
        } else {
            tranche = seniorTranche;
        }

        lender.deposit(tranche, amount);
    }

    function addLoan(AddLoanParams calldata rawParams) external {
        AddLoanParams memory params = AddLoanParams(
            rawParams.principal % structuredPortfolio.virtualTokenBalance(),
            rawParams.periodCount % 10,
            rawParams.periodPayment % (structuredPortfolio.virtualTokenBalance() / 10),
            rawParams.periodDuration % uint32(7 * DAY),
            address(borrower), /* recipient */
            uint32(DAY), /* gracePeriod */
            true /* canBeRepaidAfterDefault */
        );

        structuredPortfolio.addLoan(params);
    }

    function acceptLoan(uint256 rawLoanId) external {
        uint256 loanId = rawLoanId % 5;
        borrower.acceptLoan(fixedInterestOnlyLoans, loanId);
    }

    function fundLoan(uint256 rawLoanId) external {
        uint256 loanId = rawLoanId % 5;
        structuredPortfolio.fundLoan(loanId);
    }

    function repayLoan(uint256 rawLoanId) external {
        uint256 loanId = rawLoanId % 5;
        borrower.repayLoan(structuredPortfolio, fixedInterestOnlyLoans, loanId);
    }

    function close() public {
        structuredPortfolio.close();
    }

    function _echidna_check_waterfallContinuous() public {
        uint256[] memory waterfall_old = structuredPortfolio.calculateWaterfall();
        structuredPortfolio.updateCheckpoints();
        uint256[] memory waterfall_new = structuredPortfolio.calculateWaterfall();

        for (uint256 i = 0; i < waterfall_old.length; i++) {
            if (waterfall_new[i] != waterfall_old[i]) {
                echidna_check_waterfallContinuous = false;
            }
        }
    }

    function updateCheckpoints() public {
        structuredPortfolio.updateCheckpoints();
    }
}
